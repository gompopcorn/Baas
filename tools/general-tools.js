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

    managers.forEach(item => {
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
    
    workers.forEach(item => {
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
    inputValidationsForSwarm
}