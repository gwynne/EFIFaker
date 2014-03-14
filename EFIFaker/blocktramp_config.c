
        #define PL_BLOCKIMP_PRIVATE 1
        #include "trampoline_table.h"

        extern void *pl_blockimp_table_page;
		extern pl_trampoline_table_config pl_blockimp_table_page_config;
        pl_trampoline_table_config pl_blockimp_table_page_config = {
            .trampoline_size = 16,
            .page_offset = 128,
            .trampoline_count = 248,
            .template_page = &pl_blockimp_table_page
        };
