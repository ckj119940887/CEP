#include "verilated.h"
#include "Vaes_top.h"
#include "AES.h"

Vaes_top* top;

void evalModel() {
    top->eval();
}

void toggleClock() {
    top->wb_clk_i = ~top->wb_clk_i;
}

void waitForACK() {
    while(top->wb_ack_o == 0) {
        runForClockCycles(1);
    }
}

uint32_t readFromAddress(uint32_t pAddress) {
    top->wb_adr_i = pAddress;
    top->wb_dat_i = 0x00000000;
    top->wb_we_i = 0;
    top->wb_stb_i = 1;
    runForClockCycles(10);
    waitForACK();
    uint32_t data = top->wb_dat_o;
    top->wb_stb_i = 0;
    runForClockCycles(10);
    
    return data;
}

void writeToAddress(uint32_t pAddress, uint32_t pData) {
    top->wb_adr_i = pAddress;
    top->wb_dat_i = pData;
    top->wb_we_i = 1;
    top->wb_stb_i = 1;
    runForClockCycles(10);
    waitForACK();
    top->wb_stb_i = 0;
    top->wb_we_i = 0;
    runForClockCycles(10);
}

bool ciphertextValid(void) {
    return (readFromAddress(AES_DONE) != 0) ? true : false;
}

void start(void) {
    writeToAddress(AES_START, 0x1);
    writeToAddress(AES_START, 0x0);
}

void saveCiphertext(uint32_t *pCT) {
    for(unsigned int i = 0; i < (BLOCK_BITS / 32); ++i) {
        pCT[i] = readFromAddress(AES_CT_BASE + (i * 4));
    }
}

void reportCiphertext(void) {
    printf("Ciphertext:\t0x");
    uint32_t ct[BLOCK_BITS / 32];
    
    saveCiphertext(ct);
    for(unsigned int i = 0; i < (BLOCK_BITS / 32); ++i) {
        printf("%08X", ct[i]);
    }
    printf("\n");
}

void setPlaintext(const char* pPT) {
    printf("Plaintext:\t0x");
    for(unsigned int i = 0; i < (BLOCK_BITS / 8); ++i) {
        uint32_t temp;
        for(int j = 0; j < 4; ++j) {
            ((char *)(&temp))[3 - j] = *pPT++;
        }
        writeToAddress(AES_PT_BASE + ((3 - i) * 4), temp);
        printf("%08X", temp);
    }
    printf("\n");
}

void setPlaintext(const uint32_t* pPT) {
    printf("Plaintext:\t0x");
    for(unsigned int i = 0; i < (BLOCK_BITS / 32); ++i) {
        writeToAddress(AES_PT_BASE + ((3 - i) * 4), pPT[i]);
        printf("%08X", pPT[i]);
    }
    printf("\n");
}

void setKey(const uint32_t* pKey) {
    printf("Key:\t\t0x");
    for(unsigned int i = 0; i < (BLOCK_BITS / 32); ++i) {
        writeToAddress(AES_KEY_BASE + ((3 - i) * 4), pKey[i]);
        printf("%08X", pKey[i]);
    }
    printf("\n");
}

int main(int argc, char **argv, char **env) {
    Verilated::commandArgs(argc, argv);
    top = new Vaes_top;
    
    uint32_t ct[BLOCK_BITS / 32];
    
    printf("Initializing interface and resetting core\n");
    
    // Initialize Inputs
    top->wb_clk_i = 0;
    top->wb_dat_i = 0;
    top->wb_we_i = 0;
    top->wb_adr_i = 0;
    top->wb_stb_i = 0;
    runForClockCycles(100);
    
    printf("Reset complete\n");
    
    uint32_t pt1[4]  = {0x3243f6a8, 0x885a308d, 0x313198a2, 0xe0370734};
    uint32_t key1[4] = {0x2b7e1516, 0x28aed2a6, 0xabf71588, 0x09cf4f3c};
    setPlaintext(pt1);
    setKey(key1);
    start();
    waitForValidOutput();
    reportCiphertext();
    verifyCiphertext("3925841d02dc09fbdc118597196a0b32", "test 1");
    
    
    
    uint32_t pt2[4]  = {0x00112233, 0x44556677, 0x8899aabb, 0xccddeeff};
    uint32_t key2[4] = {0x00010203, 0x04050607, 0x08090a0b, 0x0c0d0e0f};
    setPlaintext(pt2);
    setKey(key2);
    start();
    waitForValidOutput();
    reportCiphertext();
    verifyCiphertext("69c4e0d86a7b0430d8cdb78070b4c55a", "test 2");
    
    
    
    uint32_t pt3[4]  = {0, 0, 0, 0};
    uint32_t key3[4] = {0, 0, 0, 0};
    setPlaintext(pt3);
    setKey(key3);
    start();
    waitForValidOutput();
    reportCiphertext();
    verifyCiphertext("66e94bd4ef8a2c3b884cfa59ca342b2e", "test 3");
    
    
    
    uint32_t pt4[4]  = {0, 0, 0, 0};
    uint32_t key4[4] = {0, 0, 0, 1};
    setPlaintext(pt4);
    setKey(key4);
    start();
    waitForValidOutput();
    reportCiphertext();
    verifyCiphertext("0545aad56da2a97c3663d1432a3d1c84", "test 4");
    
    
    
    uint32_t pt5[4]  = {0, 0, 0, 1};
    uint32_t key5[4] = {0, 0, 0, 0};
    setPlaintext(pt5);
    setKey(key5);
    start();
    waitForValidOutput();
    reportCiphertext();
    verifyCiphertext("58e2fccefa7e3061367f1d57a4e7455a", "test 5");
    
    top->final();
    delete top;
    exit(0);
}