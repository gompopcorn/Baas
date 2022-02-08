// node_modules
const sshClient = require('ssh2').Client;
const colors = require('colors')


function validateIPStructure(ip)
{
    let validIP = true;
    let splittedIP = ip.split(".");

    // check ip to be 4 parts separted by dots
    if (splittedIP.length !== 4) {
        validIP = false;
    }

    // check each part of IP to be a number
    splittedIP.forEach(item => {
        if (!Number(item)) {
            return validIP = false;
        }
    });

    return validIP;
}


// validate ssh username and password
async function validateSshInfo(ip, username, password)
{
    let hasAuthError = false;
    let hasOtherError = false;

    let sshValidation = await new Promise((resolve, reject) =>
    {
        const conn = new sshClient();
        conn.connect({ host: ip, username, password })
        .on('ready', () => 
        {
            conn.exec("uptime", (err, stream) => 
            {
                if (err) {
                    console.log(colors.bgRed("Error in ssh command execution in function validateSshInfo():"));
                    console.log(colors.red(err));

                    hasOtherError = true;
                    resolve(false);
                }

                stream.on('data', data => resolve(true));
            });
        
        }).on('error', err => 
        {
            // if err in authentication
            if (String(err).search("All configured authentication methods failed") !== -1) {
                hasAuthError = true;
                resolve(false);
            }

            else {
                console.log(colors.bgRed("Error in ssh validation function:"));
                console.log(colors.red(err));

                hasOtherError = true;
                resolve(false);
            }
        });
    
    });

    return {
        isValid: sshValidation,
        hasAuthError,
        hasOtherError
    }
}


// validate ssh info of servers to swarm
async function validateSshInfoForSwarm(servers, res)
{
    let isValid = null;       // ssh validation
    let status = null;       // http status
    let message = null;     // http response message

    let sshValidation = await new Promise((resolve, reject) =>
    {
        servers.forEach(async (server) =>
        {
            let sshAuthentication = await validateSshInfo(server.ip, server.username, server.password);

            // if ssh info is valid
            if (sshAuthentication.isValid) {
                return resolve({
                    isValid: true,
                    status: 200,
                    message: `Success`
                });
            }
            
            // invalid authenticate info
            else
            {
                // wrong authentication info
                if (sshAuthentication.hasAuthError) {
                    return resolve({
                        isValid: false,
                        status: 400,
                        message: `Wrong ssh authentication info for server: [${server.ip}]`
                    });
                }
    
                // connection failure
                else if (sshAuthentication.hasOtherError) {
                    return resolve({
                        isValid: false,
                        status: 400,
                        message: `Failed to authenticate ssh info for server: [${server.ip}]`
                    });
                }
    
                // some error in code
                else {
                    return resolve({
                        isValid: false,
                        status: 500,
                        message: `Some error happened in in authenticating ssh info of the server: [${server.ip}]`
                    });
                }
            }
        });
    });


    return sshValidation;
}


// docker swarm init
async function dockerSwarmInit(serverSshInfo)
{
    // docker swarm join-tokens
    let joinTokenManager;
    let joinTokenWorker;

    let hasAuthError = false;
    let hasOtherError = false;


    let swarmInit = await new Promise((resolve, reject) =>
    {
        console.log(colors.blue(`* Initializing swarm in server: [${serverSshInfo.ip}]`));

        const conn = new sshClient();
        conn.connect({ host: serverSshInfo.ip, username: serverSshInfo.username, password: serverSshInfo.password })
        .on('ready', () => 
        {
            conn.shell((err, stream) => 
            {
                if (err) {
                    console.log(colors.bgRed("Error in ssh command execution in function dockerSwarmInit():"));
                    console.log(colors.red(err));

                    hasOtherError = true;
                    resolve(false);
                }


                stream.end('docker swarm leave --force; \n\
                docker swarm init && \n\
                docker swarm join-token manager && \n\
                docker swarm join-token worker && \n\
                exit \n');

                stream.on('data', data => 
                {
                    let strData = String(data).trim();
                    // console.log(strData);

                    if (strData.search("SWMTKN") !== -1) 
                    {
                        let joinTokenAndIP = strData.slice(strData.search("SWMTKN")).split(" ");
                        let swarmIP = joinTokenAndIP[1].split(":")[0];
                        let swarmPort = joinTokenAndIP[1].split(":")[1].split("\r\n")[0];

                        if (strData.search("add a manager") !== -1) {
                            joinTokenManager = `docker swarm join --token ${joinTokenAndIP[0]} ${swarmIP}:${swarmPort}`;
                        }

                        else if (strData.search("add a worker") !== -1) {
                            joinTokenWorker = `docker swarm join --token ${joinTokenAndIP[0]} ${swarmIP}:${swarmPort}`;
                        }
                        
                        if (joinTokenManager && joinTokenWorker) {
                            return resolve({
                                manager: joinTokenManager,
                                worker: joinTokenWorker
                            });
                        }
                    }
                });
            });
        
        }).on('error', err => 
        {
            // if err in authentication
            if (String(err).search("All configured authentication methods failed") !== -1) {
                console.log(colors.bgRed("Error in ssh authentication in function dockerSwarmInit()"));
                hasAuthError = true;
                resolve(false);
            }

            else {
                console.log(colors.bgRed("Error in ssh connection in function dockerSwarmInit()"));
                console.log(colors.red(err));

                hasOtherError = true;
                resolve(false);
            }
        });
    
    });


    return {
        hasAuthError,
        hasOtherError,
        tokens: swarmInit
    }
}


// docker swarm doin
async function dockerSwarmJoin(serverSshInfo, swarmJoinCmd, role)
{
    let hasAuthError = false;
    let hasOtherError = false;


    let swarmJoin = await new Promise((resolve, reject) =>
    {
        console.log(colors.blue(`* Joining the host [${serverSshInfo.ip}] to the swarm as a ${role}`));

        const conn = new sshClient();
        conn.connect({ host: serverSshInfo.ip, username: serverSshInfo.username, password: serverSshInfo.password })
        .on('ready', () => 
        {
            conn.shell((err, stream) => 
            {
                if (err) {
                    console.log(colors.bgRed("Error in ssh command execution in function dockerSwarmJoin():"));
                    console.log(colors.red(err));

                    hasOtherError = true;
                    resolve(false);
                }

                // docker swarm join command
                stream.end(`docker swarm leave --force; ${swarmJoinCmd} && exit \n`);

                stream.on('data', data => 
                {
                    let strData = String(data).trim();
                    // console.log(strData);

                    // joined successfully
                    if (strData.search("This node joined a swarm") !== -1) {
                        return resolve(true);
                    }

                    // invalid join token - (more or less characters or invalied structure)
                    else if (strData.search("invalid join token") !== -1) {
                        console.log(colors.bgRed.black(`* Failed to join the server [${serverSshInfo.ip}] to the swarm: invalid join token`));
                        console.log(colors.red(strData));
                        hasOtherError = true;
                        return resolve(false);
                    }

                    // The swarm does not have a leader - (it can happen when the token is wrong)
                    else if (strData.search("The swarm does not have a leader") !== -1) {
                        console.log(colors.bgRed.black(`* Failed to join the server [${serverSshInfo.ip}] to the swarm: The swarm does not have a leader (or maybe wrong token)`));
                        console.log(colors.red(strData));
                        hasOtherError = true;
                        return resolve(false);
                    }

                    // Error while dialing dial tcp
                    else if (strData.search("Error while dialing dial tcp") !== -1) {
                        console.log(colors.bgRed.black(`* Failed to join the server [${serverSshInfo.ip}] to the swarm: tcp dial failed - (maybe wrong IP or port)`));
                        console.log(colors.red(strData));
                        hasOtherError = true;
                        return resolve(false);
                    }

                });
            });
        
        }).on('error', err => 
        {
            // if err in authentication
            if (String(err).search("All configured authentication methods failed") !== -1) {
                console.log(colors.bgRed("Error in ssh authentication in function dockerSwarmJoin()"));
                hasAuthError = true;
                resolve(false);
            }

            else {
                console.log(colors.bgRed("Error in ssh connection in function dockerSwarmJoin()"));
                console.log(colors.red(err));

                hasOtherError = true;
                resolve(false);
            }
        });
    
    });


    return {
        hasAuthError,
        hasOtherError,
        status: swarmJoin
    }
}


// input strucrure checking for docker swarm servers
function inputValidationsForSwarm(leader, managers, workers, res)
{
    if (!leader || !managers || !workers) {
        res.status(400).send("'leader', 'managers' and 'workers' fields are required.");
        return false;
    }

    if (typeof(leader) !== "object") {
        res.status(400).send("Leader MUST be an object");
        return false;
    }
    else if (!leader.ip || !leader.username || !leader.password) {
        res.status(400).send("Leader MUST include ip, username and password.");
        return false;
    }
    else if (!validateIPStructure(leader.ip)) {
        res.status(400).send("IP strucrure is invalid - (IPv4)");
        return false;
    }
    else if (typeof(leader.username) !== "string" || typeof(leader.password) !== "string") {
        res.status(400).send("'username' and 'password' MUST be string");
        return false;
    }


    if ( !Array.isArray(managers) || !Array.isArray(workers) || !managers.length || !workers.length ) {
        res.status(400).send("'managers' and 'workers' fields MUST be array of objects.");
        return false;
    }


    let managersTypeError = false;
    let managersLostField = false;
    let managersInvalidIP = false;
    let managersInvalidUserPass = false;

    managers.forEach(item => 
    {
        if ( typeof(item) !== "object" || Array.isArray(item) ) {
            return managersTypeError = true;
        }
        else if (!item.ip || !item.username || !item.password) {
            return managersLostField = true;
        }
        else if (!validateIPStructure(item.ip)) {
            return managersInvalidIP = true;
        }
        else if (typeof(item.username) !== "string" || typeof(item.password) !== "string") {
            return managersInvalidUserPass = true;
        }
    });

    if (managersTypeError) {
        res.status(400).send("'managers' MUST be an array of objects.");
        return false;
    }
    else if (managersLostField) {
        res.status(400).send("Each manager MUST include ip, username and password.");
        return false;
    }
    else if (managersInvalidIP) {
        res.status(400).send("Manager's ip(s) is/are INVALID");
        return false;
    }
    else if (managersInvalidUserPass) {
        res.status(400).send("Manager's 'username' and 'password' MUST be string");
        return false;
    }


    let workersTypeError = false;
    let workersLostField = false;
    let workersInvalidIP = false;
    let workersInvalidUserPass = false;
    
    workers.forEach(item => 
    {
        if ( typeof(item) !== "object" || Array.isArray(item) ) {
            return workersTypeError = true;
        }
        else if (!item.ip || !item.username || !item.password) {
            return workersLostField = true;
        }
        else if (!validateIPStructure(item.ip)) {
            return workersInvalidIP = true;
        }
        else if (typeof(item.username) !== "string" || typeof(item.password) !== "string") {
            return workersInvalidUserPass = true;
        }
    });

    if (workersTypeError) {
        res.status(400).send("'workers' MUST be an array of objects.");
        return false;
    }
    else if (workersLostField) {
        res.status(400).send("Each worker MUST include ip, username and password.");
        return false;
    }
    else if (workersInvalidIP) {
        res.status(400).send("Worker's ip(s) is/are INVALID");
        return false;
    }
    else if (workersInvalidUserPass) {
        res.status(400).send("Worker's 'username' and 'password' MUST be string");
        return false;
    }

    
    // all inputs are OK
    return true;
}




module.exports = {
    validateIPStructure,
    validateSshInfoForSwarm,
    dockerSwarmInit,
    dockerSwarmJoin,
    inputValidationsForSwarm
}