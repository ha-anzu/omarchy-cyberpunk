/* Fixed-palette SIXEL encoder. ImageMagick's quantizer drops the yellow
   on a black field, so the breach screen keeps its own colors. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int r, g, b;
} Color;

static const Color PALETTE[] = {
    {0, 0, 0},
    {252, 238, 10},
    {0, 240, 255},
    {254, 16, 56},
    {198, 182, 58},
    {110, 100, 18},
    {80, 74, 6},
    {42, 38, 8},
    {36, 31, 8},
    {20, 16, 0},
    {18, 15, 0},
    {140, 132, 8},
    {200, 188, 12},
};
#define COLORS (int)(sizeof(PALETTE) / sizeof(PALETTE[0]))

static int nearest(int r, int g, int b) {
    int i, best, best_d;
    if (r < 16 && g < 16 && b < 16) {
        return 0;
    }
    best = 1;
    best_d = 1 << 30;
    for (i = 1; i < COLORS; i++) {
        int dr = r - PALETTE[i].r;
        int dg = g - PALETTE[i].g;
        int db = b - PALETTE[i].b;
        int d = dr * dr + dg * dg + db * db;
        if (d < best_d) {
            best_d = d;
            best = i;
        }
    }
    return best;
}

static void emit_run(int count, int bits) {
    if (count <= 0) {
        return;
    }
    if (count >= 4) {
        printf("!%d%c", count, 0x3F + bits);
        return;
    }
    while (count--) {
        putchar(0x3F + bits);
    }
}

int main(int argc, char **argv) {
    int width, height, y, x, color, y0;
    size_t need, got;
    unsigned char *rgb, *idx;

    if (argc != 3) {
        return 2;
    }
    width = atoi(argv[1]);
    height = atoi(argv[2]);
    if (width < 16 || height < 16 || width > 8000 || height > 8000) {
        return 2;
    }
    need = (size_t)width * (size_t)height * 3;
    rgb = malloc(need);
    idx = malloc((size_t)width * (size_t)height);
    if (!rgb || !idx) {
        return 1;
    }
    got = fread(rgb, 1, need, stdin);
    if (got != need) {
        return 1;
    }
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            size_t o = ((size_t)y * width + x) * 3;
            idx[(size_t)y * width + x] = (unsigned char)nearest(rgb[o], rgb[o + 1], rgb[o + 2]);
        }
    }
    free(rgb);

    /* P2 = 2 paints color 0. P2 = 1 leaves those pixels transparent, and the
       desktop frames show through the black field. */
    fputs("\033P0;2;0q", stdout);
    printf("\"1;1;%d;%d", width, height);
    for (color = 0; color < COLORS; color++) {
        printf("#%d;2;%d;%d;%d", color,
               PALETTE[color].r * 100 / 255,
               PALETTE[color].g * 100 / 255,
               PALETTE[color].b * 100 / 255);
    }
    for (y0 = 0; y0 < height; y0 += 6) {
        int used[COLORS];
        int last = -1;
        int nused = 0;
        memset(used, 0, sizeof used);
        for (y = 0; y < 6 && y0 + y < height; y++) {
            for (x = 0; x < width; x++) {
                int c = idx[(size_t)(y0 + y) * width + x];
                if (!used[c]) {
                    used[c] = 1;
                    nused++;
                }
            }
        }
        for (color = 0; color < COLORS; color++) {
            int prev, run;
            if (!used[color]) {
                continue;
            }
            printf("#%d", color);
            prev = -1;
            run = 0;
            for (x = 0; x < width; x++) {
                int bits = 0;
                for (y = 0; y < 6; y++) {
                    int yy = y0 + y;
                    if (yy < height && idx[(size_t)yy * width + x] == color) {
                        bits |= 1 << y;
                    }
                }
                if (bits == prev) {
                    run++;
                } else {
                    emit_run(run, prev);
                    prev = bits;
                    run = 1;
                }
            }
            emit_run(run, prev);
            last = color;
            nused--;
            putchar(nused ? '$' : '-');
        }
        if (last < 0) {
            putchar('-');
        }
    }
    fputs("\033\\", stdout);
    free(idx);
    return 0;
}
