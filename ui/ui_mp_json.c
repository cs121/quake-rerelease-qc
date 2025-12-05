#include "ui_mp_json.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static qboolean UI_MPJSON_ReadFile(const char *path, char **out_buffer, size_t *out_length) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        return false;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return false;
    }
    long length = ftell(file);
    if (length < 0) {
        fclose(file);
        return false;
    }
    if (fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return false;
    }

    char *buffer = (char *)malloc((size_t)length + 1);
    if (!buffer) {
        fclose(file);
        return false;
    }

    size_t read_bytes = fread(buffer, 1, (size_t)length, file);
    fclose(file);
    if (read_bytes != (size_t)length) {
        free(buffer);
        return false;
    }

    buffer[length] = '\0';
    *out_buffer = buffer;
    if (out_length) {
        *out_length = (size_t)length;
    }
    return true;
}

static int UI_MPJSON_TokenLength(const jsmntok_t *tokens, int index) {
    int skip = 1;
    if (tokens[index].type == JSMN_ARRAY || tokens[index].type == JSMN_OBJECT) {
        int elements = tokens[index].size;
        int current = index + 1;
        for (int i = 0; i < elements; ++i) {
            current += UI_MPJSON_TokenLength(tokens, current);
        }
        skip = current - index;
    }
    return skip;
}

static qboolean UI_MPJSON_StringEquals(const char *json, const jsmntok_t *tok, const char *str) {
    size_t len = (size_t)(tok->end - tok->start);
    return tok->type == JSMN_STRING && strlen(str) == len && strncmp(json + tok->start, str, len) == 0;
}

static void UI_MPJSON_CopyTokenString(const char *json, const jsmntok_t *tok, char *dest, size_t dest_size) {
    size_t len = (size_t)(tok->end - tok->start);
    if (len >= dest_size) {
        len = dest_size - 1;
    }
    memcpy(dest, json + tok->start, len);
    dest[len] = '\0';
}

static qboolean UI_MPJSON_ParseItems(const char *json, const jsmntok_t *tokens, int token_count, int start_index, mp_menu_t *out_menu) {
    const jsmntok_t *array_tok = &tokens[start_index];
    if (array_tok->type != JSMN_ARRAY) {
        return false;
    }

    int index = start_index + 1;
    if (array_tok->size > (int)(sizeof(out_menu->items) / sizeof(out_menu->items[0]))) {
        return false;
    }

    for (int i = 0; i < array_tok->size; ++i) {
        if (index >= token_count) {
            return false;
        }
        const jsmntok_t *item_tok = &tokens[index];
        if (item_tok->type != JSMN_OBJECT) {
            return false;
        }

        int field_index = index + 1;
        qboolean has_label = false;
        qboolean has_command = false;
        mp_menu_item_t *item = &out_menu->items[out_menu->item_count];
        memset(item, 0, sizeof(*item));

        for (int field = 0; field < item_tok->size; ++field) {
            if (field_index + 1 >= token_count) {
                return false;
            }
            const jsmntok_t *key_tok = &tokens[field_index];
            const jsmntok_t *val_tok = &tokens[field_index + 1];

            if (UI_MPJSON_StringEquals(json, key_tok, "label")) {
                if (val_tok->type != JSMN_STRING) {
                    return false;
                }
                UI_MPJSON_CopyTokenString(json, val_tok, item->label, sizeof(item->label));
                has_label = true;
            } else if (UI_MPJSON_StringEquals(json, key_tok, "command")) {
                if (val_tok->type != JSMN_STRING) {
                    return false;
                }
                UI_MPJSON_CopyTokenString(json, val_tok, item->command, sizeof(item->command));
                has_command = true;
            }

            field_index += UI_MPJSON_TokenLength(tokens, field_index + 1) + 1;
        }

        if (!has_label || !has_command) {
            return false;
        }
        out_menu->item_count++;
        index += UI_MPJSON_TokenLength(tokens, index);
    }

    return true;
}

qboolean UI_MPMenu_LoadJSON(const char *path, mp_menu_t *out) {
    if (!path || !out) {
        return false;
    }

    char *json = NULL;
    size_t length = 0;
    if (!UI_MPJSON_ReadFile(path, &json, &length)) {
        return false;
    }

    jsmn_parser parser;
    jsmn_init(&parser);
    int token_count = jsmn_parse(&parser, json, length, NULL, 0);
    if (token_count < 0) {
        free(json);
        return false;
    }

    jsmntok_t *tokens = (jsmntok_t *)calloc((size_t)token_count, sizeof(jsmntok_t));
    if (!tokens) {
        free(json);
        return false;
    }

    jsmn_init(&parser);
    int parsed = jsmn_parse(&parser, json, length, tokens, (unsigned int)token_count);
    if (parsed < 0) {
        free(tokens);
        free(json);
        return false;
    }

    if (parsed < 1 || tokens[0].type != JSMN_OBJECT) {
        free(tokens);
        free(json);
        return false;
    }

    memset(out, 0, sizeof(*out));

    int index = 1;
    for (int obj = 0; obj < tokens[0].size; ++obj) {
        if (index + 1 >= parsed) {
            free(tokens);
            free(json);
            return false;
        }
        const jsmntok_t *key_tok = &tokens[index];
        const jsmntok_t *val_tok = &tokens[index + 1];

        if (UI_MPJSON_StringEquals(json, key_tok, "title")) {
            if (val_tok->type != JSMN_STRING) {
                free(tokens);
                free(json);
                return false;
            }
            UI_MPJSON_CopyTokenString(json, val_tok, out->title, sizeof(out->title));
        } else if (UI_MPJSON_StringEquals(json, key_tok, "items")) {
            if (!UI_MPJSON_ParseItems(json, tokens, parsed, index + 1, out)) {
                free(tokens);
                free(json);
                return false;
            }
        }

        index += UI_MPJSON_TokenLength(tokens, index + 1) + 1;
    }

    qboolean success = out->title[0] != '\0' && out->item_count > 0;
    if (success) {
        printf("UI_MPMenu_LoadJSON: loaded %d items from %s\n", out->item_count, path);
    }

    free(tokens);
    free(json);
    return success;
}

