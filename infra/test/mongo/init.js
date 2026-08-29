db = db.getSiblingDB('acceptance_test');
db.test_posts.deleteMany({});
db.test_posts.insertOne({
  _id: 'fixed-test-post',
  authorUserId: 1,
  title: 'Fixed test post',
  content: 'Deterministic integration fixture'
});
