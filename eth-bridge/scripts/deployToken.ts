import { ethers, run } from "hardhat";

async function main() {
  const Token = await ethers.getContractFactory("Token");
  console.log('starting deploying token...')
	const token = await Token.deploy('Vara', 'VARA');
	console.log('MyToken deployed with address: ' + token.address)
	console.log('wait of deploying...')
	await token.deployed()
	console.log('starting verify token...')

  try {
		await run('verify:verify', {
			address: token!.address,
			contract: 'contracts/Token.sol:Token',
			constructorArguments: [ 'MyToken', 'MTK' ],
		});
		console.log('verify success')
	} catch (e: any) {
		console.log(e.message)
	}

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


const delay = async (time: number) => {
	return new Promise((resolve: any) => {
		setInterval(() => {
			resolve()
		}, time)
	})
}
