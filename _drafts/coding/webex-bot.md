---
title: Setting Up A Webex Teams Bot
layout: post
categories: [coding]
tags: [bot, python, minegauler]
---


A webhook must be registered to receive notification of messages sent to the bot.

<https://developer.webex.com/docs/api/v1/webhooks/list-webhooks>
```json
{
  "items": [
    {
      "id": "<redacted>",
      "name": "New message to Minegauler Bot",
      "targetUrl": "http://minegauler.lewisgaul.co.uk/bot/message",
      "resource": "messages",
      "event": "created",
      "orgId": "<redacted>",
      "createdBy": "<redacted>",
      "appId": "<redacted>",
      "ownedBy": "creator",
      "status": "active",
      "created": "2020-01-16T19:07:12.612Z"
    }
  ]
}
```

