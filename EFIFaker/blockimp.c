/*
 * Author: Landon Fuller <landonf@plausible.coop>
 *
 * Copyright 2010-2011 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit
 * persons to whom the Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "blockimp.h"
#include "blockimp_private.h"

#include "trampoline_table.h"

#include <stdio.h>
#include <Block.h>
#include <pthread.h>

/* The ARM64 ABI does not require (or support) the _stret objc_msgSend variant */
#ifdef __arm64__
#define STRET_TABLE_REQUIRED 0
#define STRET_TABLE_CONFIG pl_blockimp_table_page_config
#define STRET_TABLE blockimp_table
#else
#define STRET_TABLE_REQUIRED 1
#define STRET_TABLE_CONFIG pl_blockimp_table_page_config
#define STRET_TABLE blockimp_table_stret
#endif

#pragma mark Trampolines

/* Global lock for our mutable state. Must be held when accessing the trampoline tables. */
static pthread_mutex_t blockimp_lock = PTHREAD_MUTEX_INITIALIZER;

/* Trampoline tables for objc_msgSend() dispatch. */
static pl_trampoline_table *blockimp_table = NULL;

#if STRET_TABLE_REQUIRED
/* Trampoline tables for objc_msgSend_stret() dispatch. */
static pl_trampoline_table *blockimp_table_stret = NULL;
#endif /* STRET_TABLE_REQUIRED */

/**
 * 
 */
void *pl_imp_implementationWithBlock (void *block) {

    /* Allocate the appropriate trampoline type. */
    pl_trampoline *tramp;
    struct Block_layout *bl = block;
    if (bl->flags & BLOCK_USE_STRET) {
        tramp = pl_trampoline_alloc(&STRET_TABLE_CONFIG, &blockimp_lock, &STRET_TABLE);
    } else {
        tramp = pl_trampoline_alloc(&pl_blockimp_table_page_config, &blockimp_lock, &blockimp_table);
    }
    
    /* Configure the trampoline */
    void **config = pl_trampoline_data_ptr(tramp->trampoline);
    config[0] = Block_copy(block);
    config[1] = tramp;

    /* Return the function pointer. */
    return (void *)tramp->trampoline;
}
