### Node-WhoIs

This node backend deploys an API Gateway and Lambda instance via Terraform to get return whois information on an IP address or domain. Utilizes the `whois` npm package for actual lookup functionality.


##### Deploy

`npm run-script deploy`. Builds the node project via webpack, then uses terraform to zip and upload to AWS.


##### Tests

Tests with jest. Babel used to allow ES6 language features. `npm test` to run.