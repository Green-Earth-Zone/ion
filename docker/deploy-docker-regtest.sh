#!/bin/bash
echo "SETTING UP REGTEST CONFIGURATION FOR ION"
# Get data directory for bitcoin data
# echo -n "Please enter the directory for storing the bitcoin blockchain data: "
# read bitcoinDataDirectory

bitcoinDataDirectory=$(pwd)/data/bitcoin/regtest

if [[ ! -d $bitcoinDataDirectory ]]; then
  echo "$bitcoinDataDirectory is not a directory, creating"
  mkdir -p $bitcoinDataDirectory
fi

if [[ ! -w $bitcoinDataDirectory ]]; then
  echo "Cannot write in $bitcoinDataDirectory";
fi

# Get data directory for mongo db
# echo -n "Please enter the directory for storing data for the mongo service: "
# read coreDataDirectory

coreDataDirectory=$(pwd)/data/db

if [[ ! -d $coreDataDirectory ]]; then
  echo "$coreDataDirectory is not a directory"
  mkdir -p $coreDataDirectory
fi

if [[ ! -w $coreDataDirectory ]]; then
  echo "Cannot write in $coreDataDirectory";
  exit 1
fi

# Get data directory for mongo db
# echo -n "Please enter the directory for storing data for the IPFS service: "
# read ipfsDataDirectory

ipfsDataDirectory=$(pwd)/data/ipfs

if [[ ! -d $ipfsDataDirectory ]]; then
  echo "$ipfsDataDirectory is not a directory"
  mkdir -p $ipfsDataDirectory
fi

if [[ ! -w $ipfsDataDirectory ]]; then
  echo "Cannot write in $ipfsDataDirectory";
  exit 1
fi

echo "creating containers without starting."
#create all containers, don't start them yet since they need to be started in order and will fail to start if the other service isn't running yet.
DATA_VOL=$bitcoinDataDirectory DB_VOL=$coreDataDirectory IPFS_VOL=$ipfsDataDirectory docker-compose -f docker-compose-regtest.yml up --no-start

#start IPFS and Mongo. This gives IPFS time to start finding peers
docker start mongo
docker start ipfs 
#start bitcoin main, this can take 24 hours to complete, the script will wait for it to finish
#start ion-bitcoin, this can take 12 hours
#lastly start ion-core to start the service

echo "creating config files"
# generate RPC password
# if [[ -e /dev/urandom ]]; then
#   password=$(head -c 32 /dev/urandom | base64 -)
# else
#   password=$(head -c 32 /dev/random | base64 -)
# fi

user=rpcuser
password=rpcpass

echo "
server=1
txindex=1
regtest=1
[regtest]
rpcuser=$user
rpcpassword=$password
rpcport=18443
rpcallowip=0.0.0.0/0
rpcconnect=127.0.0.1
rpcbind=0.0.0.0
" > $bitcoinDataDirectory/bitcoin.conf


# create the configuration for ION Bitcoin service
echo "
{
  \"bitcoinDataDirectory\": \"/bitcoindata/regtest\",
  \"bitcoinFeeSpendingCutoffPeriodInBlocks\": 1,
  \"bitcoinFeeSpendingCutoff\": 0.001,
  \"bitcoinPeerUri\": \"http://bitcoin-core-regtest:18443\",
  \"bitcoinRpcUsername\": \"$user\",
  \"bitcoinRpcPassword\": \"$password\",
  \"bitcoinWalletOrImportString\": \"92YboFMXfs3Ao1BhoUC8qn1nfpPwrn1VFriwnezALbXADHYq8pa\",
  \"databaseName\": \"ion-regtest-bitcoin\",
  \"genesisBlockNumber\": 100,
  \"logRequestError\": true,
  \"mongoDbConnectionString\": \"mongodb://mongo:27017/\",
  \"port\": 3002,
  \"sidetreeTransactionFeeMarkupPercentage\": 1,
  \"sidetreeTransactionPrefix\": \"ion:\",
  \"transactionPollPeriodInSeconds\": 60,
  \"valueTimeLockUpdateEnabled\": false,
  \"valueTimeLockAmountInBitcoins\": 0,
  \"valueTimeLockPollPeriodInSeconds\": 600,
  \"valueTimeLockTransactionFeesAmountInBitcoins\": 0.0001
}" > ../json/regtest-bitcoin-docker-config.json

echo "Starting up bitcoin-node service"

# start the docker bitcoin node
docker start bitcoin-core-regtest
sleep 10
echo -ne "Bitcoin-core-regtest started, please wait for this to complete a sync before proceeding
Run \"docker logs -f bitcoin-core-regtest\" to tail the current logs from the node in another session to track progress
When the logs show an entry like \"2020-07-08T03:39:41Z UpdateTip: new best=00000000324c4621bdba9b3c8f034dbe1086f643dbf1eb4f609174c8e384acca height=1534 version=0x00000001 log2_work=42.584045 tx=2476 date='2012-05-25T17:17:13Z' progress=1.000000 cache=0.3MiB(1771txo)\" ending with \"progress=1.00000\" the sync is complete

Please be patient. It takes a minute before the syncing starts and after that it can take up to 24 hours to download the entire database.
\n\n"

# wait for download
# while [ true ];
# do
#   PROGRESS=`sudo tail -n 1 $bitcoinDataDirectory/debug.log | grep -Po 'progress=\K.*?(.{5})\s'`
#   echo -ne "$PROGRESS (syncing)"\\r

#   if [[ ${PROGRESS:0:1} -eq 1 ]]; then
#     echo -ne "done"\\r
#     break;
#   fi

#   sleep 1
# done

echo -ne "Starting ion-bitcoin, please wait the service finish scanning the bitcoin blockfiles before proceeding \n
Run \"docker logs -f ion-bitcoin\" to tail the current logs from the node \n
When the log shows an entry like \"Sidetree-Bitcoin node running on port:\" the sync is complete \n"
docker start ion-bitcoin-regtest
#TODO, write piece of bash which monitors the log files and continues automatically when it's done scanning the blk files
# read

echo -ne "Starting ion-node\n"
docker start ion-core-regtest

echo -ne "Congratulations. Your ION node is running connected to bitcoin regtest. Happy resolving"
# read