/*
 * Copyright (c) 2018 MariaDB Corporation Ab
 *
 * Use of this software is governed by the Business Source License included
 * in the LICENSE.TXT file and at www.mariadb.com/bsl11.
 *
 * Change Date: 2023-10-29
 *
 * On the date above, in accordance with the Business Source License, use
 * of this software will be governed by version 2 or later of the General
 * Public License.
 */
#pragma once

#include <maxscale/ccdefs.hh>

#include <mutex>

#include "inmemorystorage.hh"

class InMemoryStorageMT : public InMemoryStorage
{
public:
    ~InMemoryStorageMT();

    typedef std::auto_ptr<InMemoryStorageMT> SInMemoryStorageMT;

    static SInMemoryStorageMT Create(const std::string& name,
                                     const Config& config,
                                     int argc,
                                     char* argv[]);

    cache_result_t get_info(uint32_t what, json_t** ppInfo) const override final;
    cache_result_t get_value(const CACHE_KEY& key,
                             uint32_t flags,
                             uint32_t soft_ttl,
                             uint32_t hard_ttl,
                             GWBUF** ppResult) override final;
    cache_result_t put_value(const CACHE_KEY& key,
                             const std::vector<std::string>& invalidation_words,
                             const GWBUF* pValue) override final;
    cache_result_t del_value(const CACHE_KEY& key) override final;
    cache_result_t invalidate(const std::vector<std::string>& words) override final;
    cache_result_t invalidate_all() override final;

private:
    InMemoryStorageMT(const std::string& name, const Config& config);

private:
    InMemoryStorageMT(const InMemoryStorageMT&);
    InMemoryStorageMT& operator=(const InMemoryStorageMT&);

private:
    mutable std::mutex m_lock;
};
