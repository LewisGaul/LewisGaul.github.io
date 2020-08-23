---
title: Setting Up A Webex Teams Bot
layout: post
categories: [coding]
tags: [bot, python, minegauler]
---

<https://developer.webex.com/docs/api/v1/webhooks/list-webhooks>
```json
{
  "items": [
    {
      "id": "<hidden>",
      "name": "New message to Minegauler Bot",
      "targetUrl": "http://minegauler.lewisgaul.co.uk/bot/message",
      "resource": "messages",
      "event": "created",
      "orgId": "<hidden>",
      "createdBy": "<hidden>",
      "appId": "<hidden>",
      "ownedBy": "creator",
      "status": "active",
      "created": "2020-01-16T19:07:12.612Z"
    }
  ]
}
```

