
3scale traffic management API v1 to v2 migration guide
======================================================

- If already using aynchronous

  - Check the responses, some of them are different. Most importantly, 'authorize' now
    responds with 200 always, except if provider_key and/or user_key (or app_id) is invalid.

    Also, the response now contains different elements. Compare the docs to see which.
    
  - report has different resposne code: 202 instead of 201. Aprat from that, it should be
    the same.
