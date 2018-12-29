#!/usr/bin/env bash

#import eosio key
cleos wallet import --private-key 5KQwrPbwdL6PhXujxW37FSSQZ1JiwsST4cqQzDeyXtP79zkvFD3

# deploy bios
cleos $remote set contract eosio ./contracts/eosio.bios/ eosio.bios.wasm eosio.bios.abi -p eosio

# create system account
SYSTEM_ACCOUNT="eosio.bpay eosio.msig eosio.names eosio.ram eosio.ramfee eosio.saving eosio.stake eosio.token eosio.vpay"

for sa in $SYSTEM_ACCOUNT
do
    echo $sa
    cleos $remote create account eosio $sa EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV EOS6MRyAjQq8ud7hVNYcfnVPJqcVpscN5So8BhtHuGYqET5GDW5CV -p eosio
done

# deploy token contract and issue
cleos $remote set contract eosio.token contracts/eosio.token eosio.token.wasm eosio.token.abi -p eosio.token

cleos $remote push action eosio.token create '["eosio", "10000000000.0000 EOS", 0, 0, 0]' -p eosio.token
cleos $remote push action eosio.token issue '["eosio", "1000000000.0000 EOS", "issue 1B to eosio"]' -p eosio

# deploy msig contract
cleos $remote set contract eosio.msig contracts/eosio.msig eosio.msig.wasm eosio.msig.abi -p eosio.msig

# deploy system contract
cleos $remote set contract eosio contracts/eosio.system eosio.system.wasm eosio.system.abi -p eosio

cleos $remote system newaccount eosio voter EOS54HgSQ9d6qjUT7pEZgbP83zQpcymR4QW1jz2jPDEdbAeKGaUif EOS54HgSQ9d6qjUT7pEZgbP83zQpcymR4QW1jz2jPDEdbAeKGaUif --stake-net "10 EOS" --stake-cpu "10 EOS" --buy-ram-kbytes 10000
cleos wallet import --private-key 5KE3vxAZ5tBXubjMeFJ9uCHHjfQeAzDqPLeW4XHGVcuKHPPLCrA
cleos $remote transfer eosio voter "200000000.0000 EOS" "transfer 200M to voter"
sleep 2 ;
cleos $remote system delegatebw voter voter '100000000.0000 EOS' '100000000.0000 EOS' -p voter



#cleos $remote push action eosio setpriv '["eosio.msig",1]' -p eosio

# create bps
ACCOUNTS="bpa bpb bpc bpd bpe bpf bpg bph bpi bpj bpk bpl bpm bpn bpo bpp bpq bpr bps bpt bpu bpv bpw bpx bpy bpz"

for acc in $ACCOUNTS
do
    echo $acc
    cleos $remote system newaccount eosio $acc EOS54HgSQ9d6qjUT7pEZgbP83zQpcymR4QW1jz2jPDEdbAeKGaUif EOS54HgSQ9d6qjUT7pEZgbP83zQpcymR4QW1jz2jPDEdbAeKGaUif --stake-cpu "1000 EOS" --stake-net "1000 EOS" --buy-ram "1000 EOS" -p eosio
    cleos $remote transfer eosio $acc "1000 EOS" "red packet" -p eosio
done

cleos $remote system regproducer bpa EOS5ZMVRKjoxdqwy3eDQkLF53uYRSvTvW8EijsD47NAkbq5GbmSH3 '' 0 -p bpa
cleos $remote system regproducer bpb EOS7WKuVc8R8X5zrfTRKbhbZuaJPKRYZqQQ6qXoXQfeS8iGK4afyk '' 0 -p bpb
cleos $remote system regproducer bpc EOS73iZuyLajqCK2WDGAmYMUb4Zr3hmpDeNSJvKJwDVkgoHcvMpjW '' 0 -p bpc
cleos $remote system regproducer bpd EOS84pKNhrH712xbjAwst9yW7nBZenAd3eZs6PYZuPYu6Y2PfC84p '' 0 -p bpd
cleos $remote system regproducer bpe EOS5nfo8X8NvHtNA8cTDSi2mdSFuBcUHtQ1ZyTdxocVtQTHjakdMg '' 0 -p bpe
cleos $remote system regproducer bpf EOS5MUtpyHQsH41rdfU6LG3urrGLozaR4i4N1Mkj39D3zyBwtw4rU '' 0 -p bpf
cleos $remote system regproducer bpg EOS6USJq2xnmsBpvoJjFcefLCtxeEvoCQTTwSqbvRg79UeCdNGzB6 '' 0 -p bpg
cleos $remote system regproducer bph EOS52rUogvuR7RjA7EHaPomAxPr4iKkGxFFFk83Mc24SusUGQxBvk '' 0 -p bph
cleos $remote system regproducer bpi EOS66RMTqXUDn7osZ2feCFZgBMEib4QNUzs9zLqTF4g2kTXWVstpg '' 0 -p bpi
cleos $remote system regproducer bpj EOS5iLrUhakDpFCNHcmrxv6xiYG3XQDTHEGt9jbJZorj1VB1LbzNX '' 0 -p bpj
cleos $remote system regproducer bpk EOS5dnfLiLQHHvBd4GqWVrVT9KtUvT1Kfm6EUMC2jXbSdVuypUGKk '' 0 -p bpk
cleos $remote system regproducer bpl EOS6qdG6S7Ev8uYEXD3nFxVvBU7iuP5F2WoYboZNvaG814nfgYiDN '' 0 -p bpl
cleos $remote system regproducer bpm EOS7YyTzTxxR87hrvNtYat5UGojJGxm3ikvPQP68KMav2WBwwA9ic '' 0 -p bpm
cleos $remote system regproducer bpn EOS6mA2BxGKbEiwDbbDPhQ1vqV4bAps49PfXuvadb8Vc4REJw1V3h '' 0 -p bpn
cleos $remote system regproducer bpo EOS7XfCLNwreuApLd1RnTSCHwZEs3BKVDp4G5uk49en6whkjnVZ6G '' 0 -p bpo
cleos $remote system regproducer bpp EOS7435EQ76dweLSHa4XBtwTVL9MVqGW1d9sm6SNPHkeEkDSp2e84 '' 0 -p bpp
cleos $remote system regproducer bpq EOS5tDFbEzjpxktdCZZgH1wERjYPHajH3LcH9TVjCF6iSJ6EVAr9t '' 0 -p bpq
cleos $remote system regproducer bpr EOS6FqJDxVzNh5CNnmktB4s2qiLzKUTH8SCjKRNTyHSYxsasdnZVA '' 0 -p bpr
cleos $remote system regproducer bpt EOS5zcM9Dweb3s96G7eY8N1FmBP98uhdSXHgAG78kJBsqyamBDvSh '' 0 -p bpt
cleos $remote system regproducer bps EOS6CyP5JLTnJ353wXdggayRm8wDMQ5YA3hVwSQ1rwVJ9Q9rsnT1x '' 0 -p bps
cleos $remote system regproducer bpu EOS5GVbsUDmuuEnQFNJdoPBTNPXhzTqRFKz6d1zgRPmdrXxg6obuL '' 0 -p bpu
cleos $remote system regproducer bpv EOS885TY14LT21h8ieV2Krxpahf17TnuCJm2wbHpWrhNcUgYUdcb3 '' 0 -p bpv
cleos $remote system regproducer bpw EOS7zVNTpr9PfLzTYybnWMn8KsMCtpsNu842rPRMxQiAAm4KFjyn1 '' 0 -p bpw
cleos $remote system regproducer bpx EOS8RufiWCXVUrSfGPirnS8zGp4nRkbZwX9ykakviAnrnP5i6mE9Y '' 0 -p bpx
cleos $remote system regproducer bpy EOS54bVNK7hvwKuhyeBTTyZpucD6LkXN6Bzw5NspoTkMaojo3poch '' 0 -p bpy
cleos $remote system regproducer bpz EOS6S5QYtt7choB6EYc7yAwUMVeBXQDhx3BR36VRhFkhwpfURr6SP '' 0 -p bpz
