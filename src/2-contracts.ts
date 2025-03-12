import {
  Hex,
  createWalletClient,
  getContract,
  http,
  publicActions,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";
//import funJson from "../artifacts/Fun.json";
import arcadeCasino from "../artifacts/ArcadeCasino.json";

import dotenv from "dotenv";

const { abi, bin } = arcadeCasino["contracts"]["contracts/ArcadeCasino.sol:ArcadeCasino"];

dotenv.config();

const privateKey = process.env.PRIVATE_KEY;
const account = privateKeyToAccount(privateKey as Hex);

(async () => {
  const client = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http(process.env.API_URL),
  }).extend(publicActions);

  //const hash = await client.deployContract({
   // abi,
  //  bytecode: `0x${bin}`,
   // args: [127n],
  //});

  //const { contractAddress } = await client.getTransactionReceipt({ hash });
  const contractAddress = process.env.CONTRACT_ADDRESS as Hex;
  const playerAddress = process.env.PLAYER_ADDRESS as Hex;

  if (contractAddress) {
    const contract = getContract({
      address: contractAddress,
      abi,
      client,
    });

    contract.read.getTickets([playerAddress]).then(console.log);

    //console.log(await contract.read.getTickets(address) 0x51d4bfAc115F338fb33173df16615868Fd483A9d);

    //console.log(await contract.read.x());
    //await contract.write.changeX([132n]);
    //console.log(await contract.read.x());

    console.log({ contractAddress });
  }
})();
