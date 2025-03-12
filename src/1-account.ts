import { Hex, createPublicClient, formatEther, http, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { arbitrumSepolia, baseSepolia } from "viem/chains";

import dotenv from "dotenv";

dotenv.config();

const privateKey = process.env.PRIVATE_KEY;
const account = privateKeyToAccount(privateKey as Hex);

console.log(account.address);

(async () => {
  const client = createPublicClient({
    chain: baseSepolia,
    transport: http(process.env.API_URL),
  });

  const balance = await client.getBalance({
    address: account.address,
  });

  console.log(formatEther(balance));

  const nonce = await client.getTransactionCount({
    address: account.address,
  });

  console.log(nonce);
})();
