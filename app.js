// node_modules
const express = require('express');
const app = express();
const path = require('path');
const colors = require('colors');
const sshClient = require('ssh2').Client;
require('dotenv').config();

const PORT = process.env.PORT;
const coreServerAddress = process.env.coreServerAddress;
const tmuxSessionName = process.env.tmuxSessionName;


app.use(express.json());  // parse application/json
app.use(express.json({type: 'application/vnd.api+json'}));  // parse application/vnd.api+json as json
app.use(express.urlencoded({ extended: true }));  // parse application/x-www-form-urlencoded



app.post('/installPreReqs', async (req, res, err) =>
{
    let serverIP = req.body.serverIP;
    let username = req.body.username;
    let password = req.body.password;
    let baasDir = process.env.baasDir;

    if (!serverIP || !username || !password) {
        return res.send("'username', 'password' and 'serverIP' fields are required.");
    }


    // ***********************************************************
    //     transfer 'install-prereqs' files to the server  AND  
    //          run pre-reqs installation files with ssh
    // ***********************************************************

    let isErrReported = false;

    try 
    {
        const conn = new sshClient();
        conn.connect({ host: serverIP, username, password })
        .on('ready', () => 
        {
            console.log(`-------- SSH connected to the server: [${serverIP}] --------\n`);
    
            conn.shell((err, stream) => 
            {
                if (err) throw err;
    
                stream.on('close', () => {
                    console.log(`\n-------- SSH DISCONNECTED from the server: [${serverIP}] --------\n`);
                    conn.end();
                })
                .on('data', (data) => {
                    console.log(colors.blue('OUTPUT: ') + data);
                });
    

                // download install-prereqs files, give permissions, create pwd.txt file and put password inside, and install-prereqs
                stream.end(`echo ${password} | sudo -S ls && history -c && \
                    sudo apt install -y unzip wget && \
                    sudo mkdir ${baasDir} && sudo chmod 777 -R ${baasDir} \n cd ${baasDir} \n\
                    wget ${coreServerAddress}/install-prereqs.zip -O install-prereqs.zip && \
                    unzip -o install-prereqs.zip && cd install-prereqs && \
                    sudo chmod +x runWithTmux.sh && sudo chmod +x install-prereqs.sh && \
                    echo ${password} > pwd.txt && history -c && \
                    ./runWithTmux.sh './install-prereqs.sh' '${tmuxSessionName}' \n\
                    exit\n`
                );


                return res.send(`Pre-requisites are being installed on your server with IP: [${serverIP}]. You can see logs by command 'tmux attach -t ${tmuxSessionName}'`)
            });
    
        })
        .on('error', err => 
        {
            console.log(colors.bgRed.black(`Error in ssh connection with the server: [${serverIP}]`));
            console.log(colors.red(err) + "\n");

            // if err in authentication
            if (String(err).search("All configured authentication methods failed") !== -1) {
                return res.status(400).send(`Authentication info is wrong`);
            }
            
            // check if error is reported before, to prevent sending response more than onece
            else if (!isErrReported) {
                isErrReported = true;
                return res.status(500).send(`Error in ssh connection with the server: [${serverIP}]`);
            }
        });
    }

    catch(err) {
        console.log(colors.bgRed.black("Error in ssh connection"));
        console.log(colors.red(err) + "\n");
        return res.status(500).send("Error in ssh connection");
    }
});


app.post('/notifications', async (req, res, err) =>
{
    let serverIP, serverIPs;
    if (req.body.serverIPs) serverIPs = req.body.serverIPs.split(" ");
    let installedPackage = req.body.installedPackage;
    let status = req.body.status;
    let networkServers;

    if (!serverIPs || !installedPackage || !status) {
        return res.send("'serverIPs', 'installedPackage' and 'status' fields are required.");
    }

    try {
        networkServers = JSON.parse(process.env.servers);
    } catch(err) {
        console.log(colors.bgRed.black("Error in parsing JSON in: ' JSON.parse(process.env.servers) '"));
        console.log(colors.red(err) + "\n");
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

    else {
        // send notification to the front-end with webDocket
       // e.g: Nodejs Installed

        // console.log(serverIP);
        console.log(req.body);
        return res.send();
    }
});


app.get('/install-prereqs.zip', (req, res) => {
    return res.sendFile(path.join(__dirname, 'install-prereqs.zip'));
})



app.listen(PORT, console.log(
    "\n**************************************************\n\n" +
    `${colors.bgWhite.black(`<--- Server started listening on Port ${PORT} --->`)}` +
    "\n\n**************************************************\n")
);