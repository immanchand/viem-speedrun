import { Hex, createPublicClient, getContract, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";
import arcadeCasino from "../artifacts/ArcadeCasino.json";

import dotenv from "dotenv";

const { abi, bin } = arcadeCasino["contracts"]["contracts/ArcadeCasino.sol:ArcadeCasino"];

dotenv.config();

const privateKey = process.env.PRIVATE_KEY;
const account = privateKeyToAccount(privateKey as Hex);
const contractAddress = process.env.CONTRACT_ADDRESS as Hex;
const playerAddress = process.env.PLAYER_ADDRESS as Hex;

(async () => {
  const client = createPublicClient({
      chain: baseSepolia,
      transport: http(process.env.API_URL),
    });

  const contract = await getContract({
    address: contractAddress,
    abi,
    client,
  });

  contract.read.getTickets([playerAddress]).then(console.log);

  // const mintEvents = await client.getContractEvents({
  //   address: contractAddress,
  //   abi,
  //   eventName: "GameTicketsMinted",
  //   fromBlock: 22966000n,
  // });

  
  //console.log(mintEvents);


  await client.watchContractEvent({
    address: contractAddress,
    abi,
    eventName: "GameTicketsMinted",
    fromBlock: 22966000n,
    onLogs: (logs) => console.log(logs),
  });

  //  await contract.watchEvent.XWasChanged({
  //    onLogs: (logs) => console.log(logs),
  //  });

  // let x = 55n;
  // setInterval(async () => {
  //   await contract.write.changeX([x]);
  //   x++;
  // }, 3000);
})();
