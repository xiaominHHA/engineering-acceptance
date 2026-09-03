const databaseName = process.env.MONGO_DATABASE;
const username = process.env.MONGO_APP_USERNAME;
const password = process.env.MONGO_APP_PASSWORD;

if (!databaseName || !username || !password) {
  throw new Error('Mongo application user environment is incomplete');
}

const applicationDatabase = db.getSiblingDB(databaseName);
if (!applicationDatabase.getUser(username)) {
  applicationDatabase.createUser({
    user: username,
    pwd: password,
    roles: [{role: 'readWrite', db: databaseName}],
  });
} else {
  applicationDatabase.updateUser(username, {
    pwd: password,
    roles: [{role: 'readWrite', db: databaseName}],
  });
}
