var LambdaForwarder = require("./email-forwarder");

exports.handler = function(event, context, callback) {
  var overrides = {
    config: {
      fromEmail: ${jsonencode(from_email)},
      emailBucket: ${jsonencode(bucket)},
      emailKeyPrefix: ${jsonencode(bucket_prefix)},
      forwardMapping: ${mapping}
    }
  };
  LambdaForwarder.handler(event, context, callback, overrides);
};
