// node_modules
const express = require('express');
const app = express();
const fs = require('fs');
const path = require('path');
const colors = require('colors');
const zipper = require("zip-local");
const sshClient = require('ssh2').Client;
require('dotenv').config();

// tools
const tools = require('./tools/general-tools.js')

const PORT = process.env.PORT;
const coreServerAddress = process.env.coreServerAddress;
const tmuxSessionName = process.env.tmuxSessionName;


app.use(express.json());  // parse application/json
app.use(express.json({type: 'application/vnd.api+json'}));  // parse application/vnd.api+json as json
app.use(express.urlencoded({ extended: true }));  // parse application/x-www-form-urlencoded



// install pre-requisites on a server
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
                    // console.log(colors.blue('OUTPUT: ') + data);
                });
    

                // download install-prereqs files, give permissions, create pwd.txt file and put password inside, and install-prereqs
                // * NOTE: the jobs will NOT be done if 'install-prereqs' directory exists in '/home/BaaS' in the target server,
                // if you want to do the jobs again, remvoe 'install-prereqs' directory from '/home/BaaS'
                stream.end(`echo ${password} | sudo -S ls && history -c && \
                    sudo apt install -y unzip wget && \
                    sudo mkdir ${baasDir}; cd ${baasDir} && sudo mkdir install-prereqs && cd install-prereqs && \
                    sudo chmod 777 -R ${baasDir} && \
                    wget ${coreServerAddress}/install-prereqs.zip -O install-prereqs.zip && \
                    unzip -o install-prereqs.zip && \
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



// swarm servers
app.post('/swarm', async (req, res) =>
{
    // * Note: each of the objects bellow MUST include: serverIP, username and password
    let leader = req.body.leader;         // swarm leader - an object
    let managers = req.body.managers;    // swarm managers - array of objects
    let workers = req.body.workers;     // swarm workers - array of objects

    // input strucrure checking
    let validateInputs =  tools.inputValidationsForSwarm(leader, managers, workers, res);

    // validate ssh info
    if (validateInputs) 
    {
        // leader ssh info authentication 
        if (leader) 
        {
            let leaderSshAuth = await tools.validateSshInfoForSwarm([leader], res);
            if (!leaderSshAuth.isValid) {
                return res.status(leaderSshAuth.status).send(leaderSshAuth.message);
            }
            else {
                console.log(colors.green("* Leader ssh authentication done successfully."));
                console.log("- " + colors.blue(leader.ip) + "\n-----------------------------------\n");
            }
        }

        // managers ssh info authentication 
        if (managers) {
            let managersSshAuth = await tools.validateSshInfoForSwarm(managers, res);
            if (!managersSshAuth.isValid) {
                return res.status(managersSshAuth.status).send(managersSshAuth.message);
            }
            else {
                console.log(colors.green("* Managers ssh authentication done successfully."));
                managers.forEach(manager => {
                    console.log("- " + colors.blue(manager.ip));
                });
                console.log("\n-----------------------------------\n");
            }
        }

        // workers ssh info authentication 
        if (workers) {
            let workersSshAuth = await tools.validateSshInfoForSwarm(workers, res);
            if (!workersSshAuth.isValid) {
                return res.status(workersSshAuth.status).send(workersSshAuth.message);
            }
            else {
                console.log(colors.green("* Workers ssh authentication done successfully."));
                workers.forEach(worker => {
                    console.log("- " + colors.blue(worker.ip));
                });
                console.log("\n-----------------------------------\n");
            }
        }

    }


    // ***********************************************************
    //                      docker swarm
    // ***********************************************************

    // checkup swarming time NOT to take a long time
    let swarmDoneFlag = false;
    setTimeout(() => {
        if (!swarmDoneFlag) {
            console.log(colors.red("Swarm init is taking long time...\n"));
            return res.status(500).send("Swarm init took long time to response. Try again.")
        }
    }, 10 * 1000);

    // init docker swarm
    let swarmInit = await tools.dockerSwarmInit(leader);
    if (!swarmInit.hasAuthError && !swarmInit.hasOtherError) {
        swarmDoneFlag = true;
        console.log(colors.green(`- Docker swarm initialized in host: [${leader.ip}]`));
        console.log(swarmInit.tokens);
        console.log("\n");
    }

    // join managers to the swarm
    if (managers)
    {
        let errHappened = false;
        let errMessage;

        await new Promise((resolve, reject) =>
        {
            managers.forEach(async (manager, index) =>
            {
                let swarmJoin = await tools.dockerSwarmJoin(manager, swarmInit.tokens.manager, "manager");
                if (swarmJoin.status) {
                    console.log(colors.green(`- Host [${manager.ip}] joined to the swarm as a manager.`));
                }
                else {
                    errMessage = `Host [${manager.ip}] FAILED joined to the swarm as a manager.`;
                    return errHappened = true;
                }


                // resolve the promise to continue the code, when all array iterations completed
                if (index === managers.length-1) resolve();
            });
        });


        if (errHappened) {
            return res.status(400).send(errMessage);
        }
    }


    // join workers to the swarm
    if (workers)
    {
        let errHappened = false;
        let errMessage;

        await new Promise((resolve, reject) =>
        {
            workers.forEach(async (worker, index) =>
            {
                let swarmJoin = await tools.dockerSwarmJoin(worker, swarmInit.tokens.worker, "worker");
                if (swarmJoin.status) {
                    console.log(colors.green(`- Host [${worker.ip}] joined to the swarm as a worker.`));
                }
                else {
                    errMessage = `Host [${worker.ip}] FAILED joined to the swarm as a worker.`;
                    return errHappened = true;
                }

                // resolve the promise to continue the code, when all array iterations completed
                if (index === workers.length-1) resolve();
            });
        });


        if (errHappened) {
            return res.status(400).send(errMessage);
        }
    }
   
    
    // docker swarm done
    return res.send("All hosts joined to the swarm successfully");
});



// recieve the status of installed packages
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


// download install-prereqs.zip file
app.get('/install-prereqs.zip', (req, res) => 
{
    // check file/directory existence
    fs.stat("./install-prereqs.zip", function(err, stat) 
    {
        // if file/directory exists
        if(err === null) {
            return res.sendFile(path.join(__dirname, 'install-prereqs.zip'));
        }

        // if file/directory NOT exists
        else if(err.code === 'ENOENT') 
        {
            try {
                zipper.sync.zip("./install-prereqs").compress().save("install-prereqs.zip");
                console.log(colors.green("\n* 'install-prereqs' folder zipped successfully.\n"));
                return res.sendFile(path.join(__dirname, 'install-prereqs.zip'));
            }
            catch(err) {
                console.log(colors.bgRed("\nError when zipping folder 'install-prereqs':"));
                console.log(colors.red(err));
                console.log("\n");
                return res.status(500).send("Failed to create zip file.")
            }
        } 
        
        // some other error
        else {
            console.log(colors.bgRed("Error in checking zip file existence:"));
            console.log(colors.red(err));
            return res.status(500).send("Error in checking zip file existence")
        }
    });
});



app.listen(PORT, console.log(
    "\n**************************************************\n\n" +
    `${colors.bgWhite.black(`<--- Server started listening on Port ${PORT} --->`)}` +
    "\n\n**************************************************\n")
);