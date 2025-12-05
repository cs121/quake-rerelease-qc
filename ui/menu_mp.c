#include "ui_mp_json.h"

#include <string.h>

// External menu functions provided by the engine
extern void M_Print(int cx, int cy, const char *str);
extern void M_DrawCharacter(int cx, int line, int num);
extern void M_DrawTextBox(int x, int y, int width, int lines);
extern void Cbuf_AddText(const char *text);

// Menu state managed by the engine
extern int m_multiplayer_cursor;
extern int m_state;
extern int m_multiplayer;
extern double realtime;

// Legacy menu entry points
extern void M_Menu_Main_f(void);
extern void M_Menu_JoinServer_f(void);
extern void M_Menu_NewGame_f(void);
extern void M_Menu_PlayerSetup_f(void);
extern void M_Menu_Options_f(void);
extern void M_StartServer_f(void);

// Quake key constants
#define K_ESCAPE 27
#define K_ENTER 13
#define K_UPARROW 128
#define K_DOWNARROW 129
#define K_MWHEELUP 239
#define K_MWHEELDOWN 240

#define CURSOR_MARGIN 8
#define MENU_LINE_HEIGHT 8

static mp_menu_t mp_menu;

// Legacy fallback used when the JSON fails to load.
static const mp_menu_item_t mp_menu_fallback_items[] = {
    {"Join Game", "menu_joinserver"},
    {"New Game", "menu_newgame"},
    {"Player Setup", "menu_playersetup"},
    {"Options", "menu_options"},
};

typedef struct {
    const char *name;
    void (*func)(void);
} ui_action_t;

static ui_action_t ui_actions[] = {
    {"menu_startserver", M_StartServer_f},
    {"menu_joinserver", M_Menu_JoinServer_f},
    {"menu_newgame", M_Menu_NewGame_f},
    {"menu_playersetup", M_Menu_PlayerSetup_f},
    {"menu_options", M_Menu_Options_f},
    {NULL, NULL}
};

void UI_MPMenu_InvokeEngineAction(const char *name) {
    if (!name) {
        return;
    }

    for (const ui_action_t *action = ui_actions; action->name; ++action) {
        if (strcmp(name, action->name) == 0 && action->func) {
            action->func();
            return;
        }
    }
}

static void MPMenu_SetFallback(void) {
    memset(&mp_menu, 0, sizeof(mp_menu));
    strncpy(mp_menu.title, "Multiplayer", sizeof(mp_menu.title) - 1);
    const int fallback_count = (int)(sizeof(mp_menu_fallback_items) / sizeof(mp_menu_fallback_items[0]));
    for (int i = 0; i < fallback_count && i < (int)(sizeof(mp_menu.items) / sizeof(mp_menu.items[0])); ++i) {
        mp_menu.items[i] = mp_menu_fallback_items[i];
    }
    mp_menu.item_count = fallback_count;
}

static void MPMenu_EnsureLoaded(void) {
    if (mp_menu.item_count) {
        return;
    }

    if (!UI_MPMenu_LoadJSON("ui/mp_menu.json", &mp_menu)) {
        MPMenu_SetFallback();
    }
}

void M_Menu_Multi_f(void) {
    MPMenu_EnsureLoaded();
    m_state = m_multiplayer;
    m_multiplayer_cursor = 0;
}

static void MPMenu_ExecuteCommand(const char *cmd) {
    if (!cmd || !cmd[0]) {
        return;
    }

    if (strncmp(cmd, "menu_", 5) == 0) {
        UI_MPMenu_InvokeEngineAction(cmd);
        return;
    }

    Cbuf_AddText(cmd);
    Cbuf_AddText("\n");
}

void M_Multi_Draw(void) {
    MPMenu_EnsureLoaded();

    int y = 32;
    if (mp_menu.title[0]) {
        M_Print(CURSOR_MARGIN, y, mp_menu.title);
        y += MENU_LINE_HEIGHT * 2;
    }

    M_DrawTextBox(CURSOR_MARGIN, y - MENU_LINE_HEIGHT, 24, mp_menu.item_count + 1);
    for (int i = 0; i < mp_menu.item_count; ++i) {
        M_Print(CURSOR_MARGIN + MENU_LINE_HEIGHT, y + MENU_LINE_HEIGHT * i, mp_menu.items[i].label);
    }

    int cursor_y = y + m_multiplayer_cursor * MENU_LINE_HEIGHT;
    M_DrawCharacter(CURSOR_MARGIN, cursor_y, 12 + ((int)(realtime * 4) & 1));
}

void M_Multi_Key(int key) {
    switch (key) {
    case K_ESCAPE:
        M_Menu_Main_f();
        break;

    case K_UPARROW:
    case K_MWHEELUP:
        if (--m_multiplayer_cursor < 0) {
            m_multiplayer_cursor = mp_menu.item_count - 1;
        }
        break;

    case K_DOWNARROW:
    case K_MWHEELDOWN:
        if (++m_multiplayer_cursor >= mp_menu.item_count) {
            m_multiplayer_cursor = 0;
        }
        break;

    case K_ENTER:
        if (m_multiplayer_cursor >= 0 && m_multiplayer_cursor < mp_menu.item_count) {
            MPMenu_ExecuteCommand(mp_menu.items[m_multiplayer_cursor].command);
        }
        break;
    }
}

