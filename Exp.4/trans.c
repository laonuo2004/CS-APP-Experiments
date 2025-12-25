/* 
 * 姓名：左逸龙
 * 学号：1120231863
 */
#include <stdio.h>
#include "cachelab.h"

int is_transpose(int M, int N, int A[N][M], int B[M][N]);

char transpose_submit_desc[] = "Transpose submission";
void transpose_submit(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, ii, jj;
    int t0, t1, t2, t3, t4, t5, t6, t7;

    if (M == 32 && N == 32) {
        /* 8x8分块，用临时变量避免对角线冲突 */
        for (i = 0; i < 32; i += 8) {
            for (j = 0; j < 32; j += 8) {
                for (ii = i; ii < i + 8; ii++) {
                    t0 = A[ii][j];   t1 = A[ii][j+1];
                    t2 = A[ii][j+2]; t3 = A[ii][j+3];
                    t4 = A[ii][j+4]; t5 = A[ii][j+5];
                    t6 = A[ii][j+6]; t7 = A[ii][j+7];
                    B[j][ii] = t0;   B[j+1][ii] = t1;
                    B[j+2][ii] = t2; B[j+3][ii] = t3;
                    B[j+4][ii] = t4; B[j+5][ii] = t5;
                    B[j+6][ii] = t6; B[j+7][ii] = t7;
                }
            }
        }
    } else if (M == 64 && N == 64) {
        /* 8x8块拆成4x4处理，利用B暂存 */
        for (i = 0; i < 64; i += 8) {
            for (j = 0; j < 64; j += 8) {
                /* 上半部分 */
                for (ii = i; ii < i + 4; ii++) {
                    t0 = A[ii][j];   t1 = A[ii][j+1];
                    t2 = A[ii][j+2]; t3 = A[ii][j+3];
                    t4 = A[ii][j+4]; t5 = A[ii][j+5];
                    t6 = A[ii][j+6]; t7 = A[ii][j+7];
                    B[j][ii] = t0;   B[j+1][ii] = t1;
                    B[j+2][ii] = t2; B[j+3][ii] = t3;
                    B[j][ii+4] = t4; B[j+1][ii+4] = t5;
                    B[j+2][ii+4] = t6; B[j+3][ii+4] = t7;
                }
                /* 调整并处理下半 */
                for (jj = j; jj < j + 4; jj++) {
                    t0 = B[jj][i+4]; t1 = B[jj][i+5];
                    t2 = B[jj][i+6]; t3 = B[jj][i+7];
                    t4 = A[i+4][jj]; t5 = A[i+5][jj];
                    t6 = A[i+6][jj]; t7 = A[i+7][jj];
                    B[jj][i+4] = t4; B[jj][i+5] = t5;
                    B[jj][i+6] = t6; B[jj][i+7] = t7;
                    B[jj+4][i] = t0; B[jj+4][i+1] = t1;
                    B[jj+4][i+2] = t2; B[jj+4][i+3] = t3;
                }
                /* 右下块 */
                for (ii = i + 4; ii < i + 8; ii++) {
                    t4 = A[ii][j+4]; t5 = A[ii][j+5];
                    t6 = A[ii][j+6]; t7 = A[ii][j+7];
                    B[j+4][ii] = t4; B[j+5][ii] = t5;
                    B[j+6][ii] = t6; B[j+7][ii] = t7;
                }
            }
        }
    } else {
        /* 一般情况用16x16分块 */
        int block = 16;
        for (i = 0; i < N; i += block) {
            for (j = 0; j < M; j += block) {
                for (ii = i; ii < i + block && ii < N; ii++) {
                    for (jj = j; jj < j + block && jj < M; jj++) {
                        B[jj][ii] = A[ii][jj];
                    }
                }
            }
        }
    }
}

char trans_desc[] = "Simple row-wise scan transpose";
void trans(int M, int N, int A[N][M], int B[M][N])
{
    int i, j, tmp;
    for (i = 0; i < N; i++) {
        for (j = 0; j < M; j++) {
            tmp = A[i][j];
            B[j][i] = tmp;
        }
    }
}

void registerFunctions()
{
    registerTransFunction(transpose_submit, transpose_submit_desc); 
    registerTransFunction(trans, trans_desc); 
}

int is_transpose(int M, int N, int A[N][M], int B[M][N])
{
    int i, j;
    for (i = 0; i < N; i++) {
        for (j = 0; j < M; ++j) {
            if (A[i][j] != B[j][i]) return 0;
        }
    }
    return 1;
}
