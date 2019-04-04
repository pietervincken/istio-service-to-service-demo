const restify = require('restify');
const restifyPromise = require('restify-await-promise');

const server = restify.createServer();
const nano = require('nano')('http://couchdb');

let apiIsReady = false;
restifyPromise.install(server);
let store = null;

/**
 * Initialise the database
 */
const init = async () => {
    try {
        await nano.db.create('animals')
    } catch (error) {
        console.info(error);
        //if the database already exists, just use it.
    }
    apiIsReady = true;
    store = nano.use('animals')

};
init();

/**
 * GET /api/v1/animals/:name
 * Fetch a single animal by name. 
 */
server.get('/api/v1/animals/:name', async function (req) {
    try {
        let animal = await store.get(req.params.name);
        return animal;
    } catch (error) {
        if (error.statusCode === 404) {
            return {
                statusCode: 404,
                message: 'Not found'
            }
        } else {
            console.error(error);
            return {
                statusCode: 500,
                message: 'Something went wrong.'
            }
        }
    }
});

/**
 * GET /_up
 * Liveness call
 */
server.get('/_up', async (req) => {
    return {
        statusCode: 200,
        status: 'ok'
    }
});

/**
 * GET /_ready
 * Readiness call
 */
server.get('/_ready', async (req) => {
    return {
        statusCode: (apiIsReady) ? (200) : (502),
        status: (apiIsReady) ? ('ok') : ('not available yet!')
    }
});

/**
 * Start the server.
 */
server.listen(8080, function () {
    console.log('ready on %s', server.url);
});