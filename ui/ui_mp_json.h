#ifndef UI_MP_JSON_H
#define UI_MP_JSON_H

#include "jsmn.h"
#include <stddef.h>

#ifndef qboolean
#define qboolean int
#endif

#ifndef true
#define true 1
#endif

#ifndef false
#define false 0
#endif

typedef struct {
    char label[64];
    char command[128];
} mp_menu_item_t;

typedef struct {
    char title[64];
    int item_count;
    mp_menu_item_t items[32];
} mp_menu_t;

qboolean UI_MPMenu_LoadJSON(const char *path, mp_menu_t *out);

#endif /* UI_MP_JSON_H */
