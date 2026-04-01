// SNOW-V 32-bit reference-style implementation S-BOX FAULT
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <inttypes.h>

typedef uint8_t  u8;
typedef uint16_t u16;
typedef uint32_t u32;

/* ------------------ Fault / Attack Control ------------------ */

int fault_active = 0;   // 0 = no fault, 1 = fault enabled
int aes_round;
FILE *ffaultlog = NULL;
FILE *ft1 = NULL;

uint64_t fault_total = 0;
uint64_t fault_init = 0;
uint64_t fault_run = 0;

uint64_t fault_R2 = 0;
uint64_t fault_R3 = 0;

uint64_t fault_t = 0;
uint64_t keystream_counter = 0;

/* AES S-Box (256 bytes) */
u8 SBox[256] =
{
    0x63,0x7C,0x77,0x7B,0xF2,0x6B,0x6F,0xC5,0x30,0x01,0x67,0x2B,0xFE,0xD7,0xAB,0x76,
    0xCA,0x82,0xC9,0x7D,0xFA,0x59,0x47,0xF0,0xAD,0xD4,0xA2,0xAF,0x9C,0xA4,0x72,0xC0,
    0xB7,0xFD,0x93,0x26,0x36,0x3F,0xF7,0xCC,0x34,0xA5,0xE5,0xF1,0x71,0xD8,0x31,0x15,
    0x04,0xC7,0x23,0xC3,0x18,0x96,0x05,0x9A,0x07,0x12,0x80,0xE2,0xEB,0x27,0xB2,0x75,
    0x09,0x83,0x2C,0x1A,0x1B,0x6E,0x5A,0xA0,0x52,0x3B,0xD6,0xB3,0x29,0xE3,0x2F,0x84,
    0x53,0xD1,0x00,0xED,0x20,0xFC,0xB1,0x5B,0x6A,0xCB,0xBE,0x39,0x4A,0x4C,0x58,0xCF,
    0xD0,0xEF,0xAA,0xFB,0x43,0x4D,0x33,0x85,0x45,0xF9,0x02,0x7F,0x50,0x3C,0x9F,0xA8,
    0x51,0xA3,0x40,0x8F,0x92,0x9D,0x38,0xF5,0xBC,0xB6,0xDA,0x21,0x10,0xFF,0xF3,0xD2,
    0xCD,0x0C,0x13,0xEC,0x5F,0x97,0x44,0x17,0xC4,0xA7,0x7E,0x3D,0x64,0x5D,0x19,0x73,
    0x60,0x81,0x4F,0xDC,0x22,0x2A,0x90,0x88,0x46,0xEE,0xB8,0x14,0xDE,0x5E,0x0B,0xDB,
    0xE0,0x32,0x3A,0x0A,0x49,0x06,0x24,0x5C,0xC2,0xD3,0xAC,0x62,0x91,0x95,0xE4,0x79,
    0xE7,0xC8,0x37,0x6D,0x8D,0xD5,0x4E,0xA9,0x6C,0x56,0xF4,0xEA,0x65,0x7A,0xAE,0x08,
    0xBA,0x78,0x25,0x2E,0x1C,0xA6,0xB4,0xC6,0xE8,0xDD,0x74,0x1F,0x4B,0xBD,0x8B,0x8A,
    0x70,0x3E,0xB5,0x66,0x48,0x03,0xF6,0x0E,0x61,0x35,0x57,0xB9,0x86,0xC1,0x1D,0x9E,
    0xE1,0xF8,0x98,0x11,0x69,0xD9,0x8E,0x94,0x9B,0x1E,0x87,0xE9,0xCE,0x55,0x28,0xDF,
    0x8C,0xA1,0x89,0x0D,0xBF,0xE6,0x42,0x68,0x41,0x99,0x2D,0x0F,0xB0,0x54,0xBB,0x16
};
u8 SBox_faulty[256] =
{
    0x63,0x63,0x77,0x7B,0xF2,0x6B,0x6F,0xC5,0x30,0x01,0x67,0x2B,0xFE,0xD7,0xAB,0x76,
    0xCA,0x82,0xC9,0x7D,0xFA,0x59,0x47,0xF0,0xAD,0xD4,0xA2,0xAF,0x9C,0xA4,0x72,0xC0,
    0xB7,0xFD,0x93,0x26,0x36,0x3F,0xF7,0xCC,0x34,0xA5,0xE5,0xF1,0x71,0xD8,0x31,0x15,
    0x04,0xC7,0x23,0xC3,0x18,0x96,0x05,0x9A,0x07,0x12,0x80,0xE2,0xEB,0x27,0xB2,0x75,
    0x09,0x83,0x2C,0x1A,0x1B,0x6E,0x5A,0xA0,0x52,0x3B,0xD6,0xB3,0x29,0xE3,0x2F,0x84,
    0x53,0xD1,0x00,0xED,0x20,0xFC,0xB1,0x5B,0x6A,0xCB,0xBE,0x39,0x4A,0x4C,0x58,0xCF,
    0xD0,0xEF,0xAA,0xFB,0x43,0x4D,0x33,0x85,0x45,0xF9,0x02,0x7F,0x50,0x3C,0x9F,0xA8,
    0x51,0xA3,0x40,0x8F,0x92,0x9D,0x38,0xF5,0xBC,0xB6,0xDA,0x21,0x10,0xFF,0xF3,0xD2,
    0xCD,0x0C,0x13,0xEC,0x5F,0x97,0x44,0x17,0xC4,0xA7,0x7E,0x3D,0x64,0x5D,0x19,0x73,
    0x60,0x81,0x4F,0xDC,0x22,0x2A,0x90,0x88,0x46,0xEE,0xB8,0x14,0xDE,0x5E,0x0B,0xDB,
    0xE0,0x32,0x3A,0x0A,0x49,0x06,0x24,0x5C,0xC2,0xD3,0xAC,0x62,0x91,0x95,0xE4,0x79,
    0xE7,0xC8,0x37,0x6D,0x8D,0xD5,0x4E,0xA9,0x6C,0x56,0xF4,0xEA,0x65,0x7A,0xAE,0x08,
    0xBA,0x78,0x25,0x2E,0x1C,0xA6,0xB4,0xC6,0xE8,0xDD,0x74,0x1F,0x4B,0xBD,0x8B,0x8A,
    0x70,0x3E,0xB5,0x66,0x48,0x03,0xF6,0x0E,0x61,0x35,0x57,0xB9,0x86,0xC1,0x1D,0x9E,
    0xE1,0xF8,0x98,0x11,0x69,0xD9,0x8E,0x94,0x9B,0x1E,0x87,0xE9,0xCE,0x55,0x28,0xDF,
    0x8C,0xA1,0x89,0x0D,0xBF,0xE6,0x42,0x68,0x41,0x99,0x2D,0x0F,0xB0,0x54,0xBB,0x16
};

/* Sigma permutation table (reference) */
u8 Sigma[16] = {0,4,8,12,1,5,9,13,2,6,10,14,3,7,11,15};
u32 AesKey1[4] = {0,0,0,0};
u32 AesKey2[4] = {0,0,0,0};

#define MAKEU32(a,b) (((u32)(a) << 16) | ((u32)(b)))
#define MAKEU16(a,b) (((u16)(a) << 8)  | ((u16)(b)))

/* ------------------ SNOW-V state ------------------ */
u16 A[16], B[16]; /* LFSRs */
u32 R1[4], R2[4], R3[4];  /* FSM registers */
/* ------------------ Field polynomials ------------------ */

#define A_POLY      0x990F   // α reduction polynomial
#define A_POLY_INV  0xCC87   // α^{-1} polynomial
#define B_POLY      0xC963   // β reduction polynomial
#define B_POLY_INV  0xE4B1   // β^{-1} polynomial

// Multiply by x in F2^16
u16 mul_x(u16 v, u16 poly)
{
    if (v & 0x8000)
        return (v << 1) ^ poly;
    else
        return (v << 1);
}

// Multiply by x^-1 in F2^16
u16 mul_x_inv(u16 v, u16 poly_inv)
{
    if (v & 0x0001)
        return (v >> 1) ^ poly_inv;
    else
        return (v >> 1);
}

/* ------------------ Sigma permutation ------------------ */
void permute_sigma(u32 *state)
 {
    u8 tmp[16];
    /* extract bytes (little-endian mapping) */
    for (int i = 0; i < 16; i++)
        tmp[i] = (u8)(state[Sigma[i] >> 2] >> ((Sigma[i] & 3) << 3));
    /* pack according to Sigma mapping */
    for (int i = 0; i < 4; i++)
    {
        state[i] = MAKEU32(MAKEU16(tmp[4 * i + 3], tmp[4 * i + 2]),MAKEU16(tmp[4 * i + 1], tmp[4 * i]));
    }


}
/* ------------------ AES-like single round used in FSM ------------------ */
void aes_enc_round(u32 *result,u32 *state,u32 *roundKey)
{
    #define ROTL32(word32, offset) ((word32 << offset) | (word32 >> (32 - offset)))
    #define SB(index, offset) (((u32)(sb[(index) % 16])) << (offset * 8))
    #define MKSTEP(j)\
          w = SB(j * 4 + 0, 3) | SB(j * 4 + 5, 0) | SB(j * 4 + 10, 1) | SB(j * 4 + 15, 2);\
          t = ROTL32(w, 16) ^ ((w << 1) & 0xfefefefeUL) ^ (((w >> 7) & 0x01010101UL) * 0x1b);\
          result[j] = roundKey[j] ^ w ^ t ^ ROTL32(t, 8)

          u32 w, t;
          u8 sb[16];
          for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
        u8 x = (state[i] >> (j * 8)) & 0xff;
        u8 y_correct = SBox[x];
        u8 y_faulty  = SBox_faulty[x];

        /* Inject fault ONLY at (0,0) */
        if (fault_active && i == 0 && j == 0) {
            sb[i * 4 + j] = y_faulty;

            /* Count ONLY effective faults */
            if (y_faulty != y_correct) {
                fault_total++;

                if (keystream_counter < 16)
                    fault_init++;
                else
                    fault_run++;

                /* Log ONLY real effective fault: 7c -> 63 */
                if (y_correct == 0x7c && y_faulty == 0x63) {
                    if (aes_round == 1) {
                        fault_R2++;
                        fprintf(ffaultlog, "%" PRIu64 " R2\n", keystream_counter);
                    } else if (aes_round == 2) {
                        fault_R3++;
                        fprintf(ffaultlog, "%" PRIu64 " R3\n", keystream_counter);
                    }
                }
            }
        }
        else {
            sb[i * 4 + j] = y_correct;
        }
    }
}

MKSTEP(0);
MKSTEP(1);
MKSTEP(2);
MKSTEP(3);

}
/* ------------------ FSM update ------------------ */
void fsm_update(void)
{
    u32 R1temp[4];
    memcpy(R1temp, R1, sizeof(R1));

    for (int i = 0; i < 4; i++)
        {
            u32 T2 = MAKEU32(A[2 * i + 1], A[2 * i]);
            R1[i] = (T2 ^ R3[i]) + R2[i];
        }
permute_sigma(R1);
/* AES on R3: log as aes_round = 2 */
    aes_round = 2;
    aes_enc_round(R3, R2, AesKey2);

    /* AES on R2: log as aes_round = 1 */
    aes_round = 1;
    aes_enc_round(R2, R1temp, AesKey1);

    /* Reset aes_round */
    aes_round = 0;
}

/* ------------------ LFSR update------------------ */
void lfsr_update(void) {
    /* perform 8 internal 16-bit steps */
    for (int i = 0; i < 8; i++)
    {
        u16 u = mul_x(A[0], 0x990f) ^ A[1] ^ mul_x_inv(A[8], 0xcc87) ^ B[0];
        u16 v = mul_x(B[0], 0xc963) ^ B[3] ^ mul_x_inv(B[8], 0xe4b1) ^ A[0];

         for (int j = 0; j < 15; j++)
         {
              A[j] = A[j + 1];
              B[j] = B[j + 1];
         }
         A[15] = u;
         B[15] = v;
    }
}

/* ------------------ Keystream generation ------------------ */
void keystream(u8 *z)
{
    keystream_counter++;
    /* T1 = (b15..b8) forming 4 words */
    for (int i = 0; i < 4; i++)
        {
            u32 T1 = MAKEU32(B[2 * i + 9], B[2 * i + 8]);
    /* -------- STORE T1 (byte-wise) -------- */
    u8 t1_b0 = (T1 >> 0) & 0xff;
    u8 t1_b1 = (T1 >> 8) & 0xff;
    u8 t1_b2 = (T1 >> 16) & 0xff;
    u8 t1_b3 = (T1 >> 24) & 0xff;

     if (!fault_active && keystream_counter > 16)
    {
        fprintf(ft1, "%02x %02x %02x %02x ", t1_b0, t1_b1, t1_b2, t1_b3);
    }

            u32 v = (T1 + R1[i]) ^ R2[i];
            z[i * 4 + 0] = (v >> 0) & 0xff;
            z[i * 4 + 1] = (v >> 8) & 0xff;
            z[i * 4 + 2] = (v >> 16) & 0xff;
            z[i * 4 + 3] = (v >> 24) & 0xff;
        }
        if (!fault_active && keystream_counter > 16)
{
    fprintf(ft1, "\n");
}

    /* update FSM and LFSRs for next block */
    fsm_update();
    lfsr_update();
}
/* ------------------ Initialization------------------ */
/* key: 32 bytes  */
/* iv: 16 bytes  */

void keyiv_setup(u8 *key,u8 *iv, int is_aead_mode)
 {
    for (int i = 0; i < 8; i++)
        {
            A[i] = MAKEU16(iv[2 * i + 1], iv[2 * i]);    /* A[7..0]  <- iv7..iv0 */
            A[i + 8] = MAKEU16(key[2 * i + 1], key[2 * i]);  /* A[15..8] <- k7..k0*/
            B[i] = 0x0000;    /* B[7..0] <- 0 */
            B[i + 8] = MAKEU16(key[2 * i + 17], key[2 * i + 16]);  /* B[15..8] <- k15..k8 (key[16..31]) */
        }

    if(is_aead_mode == 1)
        {
            B[0] = 0x6C41;
            B[1] = 0x7865;
            B[2] = 0x6B45;
            B[3] = 0x2064;
            B[4] = 0x694A;
            B[5] = 0x676E;
            B[6] = 0x6854;
            B[7] = 0x6D6F;
        }
    /* Initialize FSM regs to zero */
    for (int i = 0; i < 4; i++)
        R1[i] = R2[i] = R3[i] = 0x00000000;
/* Warm-up: 16 iterations as in Algorithm 1 lines 7-14
   For each t produce z, fold into A[8..15], and on t=15,16 XOR R1 with key segments
*/
    for (int i = 0; i < 16; i++)
    {
         u8 z[16];
         keystream(z);
         /* Print warm-up z line (16 bytes, space separated) */
        for (int j = 0; j < 8; j++)
            A[j + 8] ^= MAKEU16(z[2 * j + 1], z[2 * j]);

        if (i == 14)
            for (int j = 0; j < 4; j++)
                {
                  R1[j] ^= MAKEU32(MAKEU16(key[4 * j + 3], key[4 * j + 2]),MAKEU16(key[4 * j + 1], key[4 * j + 0]));
                }
        if (i == 15)
            for (int j = 0; j < 4; j++)
                {
                    R1[j] ^= MAKEU32(MAKEU16(key[4 * j + 19], key[4 * j + 18]),MAKEU16(key[4 * j + 17], key[4 * j + 16]));

                }
    }


}

/* ------------------ Main Function ------------------ */
int main(void)
{
    u8 key[32];
    u8 iv[16];
    unsigned int w;

    printf("--- SNOW-V S-Box fault Model Simulation ---\n\n");
  // --- Take direct 32-byte key input (hex) ---
printf("Enter 32 bytes of key in hex (64 hex chars):\n");
for (int i = 0; i < 32; i++) {
    scanf("%2x", &w);
    key[i] = (u8)w;
}

// --- Take direct 16-byte IV input ---
printf("Enter 16 bytes of IV in hex (32 hex chars):\n");
for (int i = 0; i < 16; i++) {
    scanf("%2x", &w);
    iv[i] = (u8)w;
}

u8 z[16];

FILE *fclean  = fopen("keystream_clean.txt", "w");
FILE *ffaulty = fopen("keystream_faulty.txt", "w");

ft1 = fopen("t1_values.txt", "w");
if (!ft1) {
    printf("Error opening t1_values.txt\n");
    return 1;
}

ffaultlog = fopen("fault_positions.txt", "w");
if (!ffaultlog) {
    printf("Error opening fault_positions.txt\n");
    return 1;
}

/* ================= CLEAN RUN ================= */
fault_active = 0;
keystream_counter = 0;
printf("\nInitialization clean phase, z:\n");
keyiv_setup(key, iv, 0);
printf("\nKeystream clean phase (128-bit z):\n");
for (int i = 0; i < 1000000; i++)
{
    keystream(z);
for (int j = 0; j < 16; j++)
        fprintf(fclean, "%02x ", z[j]);
    fprintf(fclean, "\n");

}

/* ================= FAULTY RUN ================= */

fault_active = 1;
keystream_counter = 0;
printf("\nInitialization faulty phase, z:\n");
keyiv_setup(key, iv, 0);
printf("\nKeystream faulty  phase (128-bit z):\n");
for (int i = 0; i < 1000000; i++)
{
    keystream(z);
for (int j = 0; j < 16; j++)
        fprintf(ffaulty, "%02x ", z[j]);
    fprintf(ffaulty, "\n");

}
fclose(fclean);
fclose(ffaulty);
fclose(ft1);
fclose(ffaultlog);
printf("\n--- S-box Fault Forensics ---\n");
printf("Total faulty S-box hits       : %llu\n", fault_total);
printf("Faults during init (t<16)     : %llu\n", fault_init);
printf("Faults during running (t>=16) : %llu\n", fault_run);
printf("Faults affecting R2           : %llu\n", fault_R2);
printf("Faults affecting R3           : %llu\n", fault_R3);

printf("\n Done.\n");
    return 0;
}
