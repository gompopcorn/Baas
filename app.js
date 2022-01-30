// node_modules
const express = require('express');
const app = express();
const colors = require('colors');
const { Client } = require('node-scp');
require('dotenv').config();

const PORT = process.env.PORT;


// app.options('*', cors());
// app.use(cors());

app.use(express.json());  // parse application/json
app.use(express.json({type: 'application/vnd.api+json'}));  // parse application/vnd.api+json as json
app.use(express.urlencoded({ extended: true }));  // parse application/x-www-form-urlencoded



app.post('/installPreReqs', async (req, res, err) =>
{
    let serverIP = req.body.serverIP;
    let username = req.body.username;
    let password = req.body.password;

    // if (!serverIP || !username || !password) {
    //     return res.send("'username', 'password' and 'serverIP' fields are required.");
    // }

    // try {
    //     const client = await Client({
    //         host: serverIP,
    //         username,
    //         password
    //     });
    // }
    // catch(err) {
    //     console.log(err);
    // }
});


app.post('/notifications', async (req, res, err) =>
{
    let serverIP, serverIPs = req.body.serverIPs.split(" ");
    let installedPackage = req.body.installedPackage;
    let status = req.body.status;
    let networkServers;

    // return console.log(installedPackage);

    try {
        networkServers = JSON.parse(process.env.servers);
    } catch(err) {
        console.log(colors.bgRed.black("Error in parsing JSON in: ' JSON.parse(process.env.servers) '"));
        console.log(colors.red(err));
        console.log("\n");
    }

    if (!serverIPs || !installedPackage || !status) {
        return res.send("'serverIPs', 'installedPackage' and 'status' fields are required.");
    }

    // find the ip of the server from networkServers
    serverIPs.forEach(ip => {
        for (let server in networkServers) {
            if (ip === networkServers[server]) {
                return serverIP = ip;
            }
        }
    });

    if (!serverIP) {
        return res.status(404).send(`There is no server with any of IPs: ${serverIPs}`)
    }

     // send notification to the front-end with webDocket
    // e.g: Nodejs Installed

    
});



app.listen(PORT, console.log(
    "\n**************************************************\n\n" +
    `${colors.bgWhite.black(`<--- Server started listening on Port ${PORT} --->`)}` +
    "\n\n**************************************************\n")
);



async function test() 
{
    try 
    {
        const client = await Client({
            host: '194.5.193.217',
            username: 'ubuntu',
            password: 's@popcorn2001'
        });

        // await client.uploadFile('./runWithTmux.sh', '/home/ubuntu/Baas/runWithTmux2.sh');
        // await client.uploadDir('./test', '/home/ubuntu/Baas/test')

        // await client.downloadFile('/home/ubuntu/Baas/runWithTmux2.sh', './runWithTmux2.sh')

        // await client.mkdir('/home/ubuntu/Baas/hello');

        // const result = await client.exists('/home/ubuntu/Baas/README.md');
        // const result = await client.stat('/home/ubuntu/Baas');
        // const result = await client.list('/home/ubuntu/Baas');
        console.log(result);
        
        client.close() // remember to close connection after you finish
    } 
    
    catch (e) {
        console.log(e)
    }
}

// test()