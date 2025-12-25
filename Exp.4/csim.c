/*
 * 姓名：左逸龙
 * 学号：1120231863
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>
#include "cachelab.h"

typedef struct {
    int valid;
    unsigned long tag;
    int lru;
} CacheLine;

static int s = 0, E = 0, b = 0, verbose = 0;
static char *tracefile = NULL;
static int hits = 0, misses = 0, evictions = 0;
static CacheLine **cache = NULL;
static int lru_clock = 0;

void printUsage(char *argv0) {
    printf("Usage: %s [-hv] -s <s> -E <E> -b <b> -t <tracefile>\n", argv0);
}

void initCache() {
    int S = 1 << s;
    cache = (CacheLine **)malloc(S * sizeof(CacheLine *));
    for (int i = 0; i < S; i++) {
        cache[i] = (CacheLine *)calloc(E, sizeof(CacheLine));
    }
}

void freeCache() {
    int S = 1 << s;
    for (int i = 0; i < S; i++)
        free(cache[i]);
    free(cache);
}

void accessCache(unsigned long addr) {
    unsigned long set_idx = (addr >> b) & ((1UL << s) - 1);
    unsigned long tag = addr >> (s + b);
    CacheLine *set = cache[set_idx];

    /* 查找命中 */
    for (int i = 0; i < E; i++) {
        if (set[i].valid && set[i].tag == tag) {
            hits++;
            set[i].lru = lru_clock++;
            if (verbose) printf("hit ");
            return;
        }
    }

    /* 未命中 */
    misses++;
    if (verbose) printf("miss ");

    /* 找空行或LRU替换 */
    int victim = 0, min_lru = set[0].lru;
    for (int i = 0; i < E; i++) {
        if (!set[i].valid) { victim = i; goto load; }
        if (set[i].lru < min_lru) { min_lru = set[i].lru; victim = i; }
    }
    evictions++;
    if (verbose) printf("eviction ");

load:
    set[victim].valid = 1;
    set[victim].tag = tag;
    set[victim].lru = lru_clock++;
}

void processTrace() {
    FILE *fp = fopen(tracefile, "r");
    if (!fp) { fprintf(stderr, "Cannot open %s\n", tracefile); exit(1); }

    char line[256], op;
    unsigned long addr;
    int size;

    while (fgets(line, sizeof(line), fp)) {
        if (line[0] == 'I') continue;
        if (sscanf(line, " %c %lx,%d", &op, &addr, &size) == 3) {
            if (verbose) printf("%c %lx,%d ", op, addr, size);
            if (op == 'L' || op == 'S') accessCache(addr);
            else if (op == 'M') { accessCache(addr); accessCache(addr); }
            if (verbose) printf("\n");
        }
    }
    fclose(fp);
}

int main(int argc, char *argv[]) {
    int opt;
    while ((opt = getopt(argc, argv, "hvs:E:b:t:")) != -1) {
        switch (opt) {
            case 'h': printUsage(argv[0]); return 0;
            case 'v': verbose = 1; break;
            case 's': s = atoi(optarg); break;
            case 'E': E = atoi(optarg); break;
            case 'b': b = atoi(optarg); break;
            case 't': tracefile = optarg; break;
            default: printUsage(argv[0]); return 1;
        }
    }

    if (s <= 0 || E <= 0 || b <= 0 || !tracefile) {
        fprintf(stderr, "Missing required arguments\n");
        printUsage(argv[0]);
        return 1;
    }

    initCache();
    processTrace();
    freeCache();
    printSummary(hits, misses, evictions);
    return 0;
}
