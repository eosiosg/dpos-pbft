#!/usr/bin/env bash

# set -ex

SELECTED=()

shuffle_and_select_bps(){
  N=7
  # N=21
  # BPS=( bpa bpb bpc bpd bpe bpf bpg bph bpi bpj bpk bpl bpm bpn bpo bpp bpq bpr bps bpt bpu bpv bpw bpx bpy bpz )
  BPS=( bpa bpb bpc bpd bpe bpf bpg bph bpi )
  tmp=()
  for index in $(shuf --input-range=0-$(( ${#BPS[*]} - 1 )) -n ${N})
  do
      tmp+=(${BPS[$index]})
  done
  SELECTED=($(echo "${tmp[@]}" | sed 's/ /\n/g' | sort))
}

shuffle_and_select_bps
# new_array=($(echo "${SELECTED[@]}" | sed 's/ /\n/g' | sort))
echo ${SELECTED[@]}

while :
do
shuffle_and_select_bps
cleos $remote system voteproducer prods voter  ${SELECTED[*]} -p voter
echo "sleep 10 seconds"
sleep 10
done



# N=11
# BPS=( bpa bpb bpc bpd bpe bpf bpg bph bpi bpj bpk bpl bpm bpn )
# SELECTED=()
# for index in $(shuf --input-range=0-$(( ${#BPS[*]} - 1 )) -n ${N})
# do
#     echo "selecte: ${BPS[$index]}"
#     SELECTED+=(${BPS[$index]})
# done
#
# echo ${BPS[*]}
# echo ${SELECTED[*]}
#
# while :
# do
# cleos $remote system voteproducer prods voter -p voter
# echo "sleep 120 seconds"
# sleep 120
#
# cleos $remote system voteproducer prods voter -p voter
# echo "sleep 120 seconds"
# sleep 120
#
# cleos $remote system voteproducer prods voter -p voter
# echo "sleep 120 seconds"
# sleep 120
#
# done
# bpa bpb bpc bpd bpe bpf bpg bph bpi bpj bpk bpl bpm bpn
