# 3scale API Management System Backend

This is 3scale's kick-ass ultra-scalable API management system backend.

## Deploy

1. Update the version.
  1. Modify `lib/3scale/backend/version.rb`.
  2. Execute `bundle install`.
  3. Git commit and push.
2. Package the project as a gem and upload it to our private gem server.
You can do it executing: `script/release`
3. Follow the steps described in deploy project.
