---
title: Adding Comments To The Blog
layout: post
categories: [coding]
tags: [website, blog]
---

Following instructions and example at:

<http://www.gabescode.com/staticman/2019/01/04/staticman-comments-for-jekyll.html>  
<http://www.gabescode.com/staticman/2019/01/03/create-staticman-instance.html>

Using Staticman:

<https://staticman.net/>  
<https://github.com/eduardoboucas/staticman#setting-up-the-server-on-your-own-infrastructure>  
<https://github.com/eduardoboucas/staticman-recaptcha>



## Setting up Staticman

<http://www.gabescode.com/staticman/2019/01/03/create-staticman-instance.html>

<https://github.com/LewisGaul/staticman/tree/blog>


### Create a new GitHub bot account

You could let Staticman use your own personal GitHub account, but I set up a bot account.

GitHub does allow you to create a separate account for automation. To quote their Differences between user and organization accounts article:

> User accounts are intended for humans, but you can give one to a robot, such as a continuous integration bot, if necessary.

A bot account on GitHub really is no different than any other user account. So to create it, just log out of your own GitHub account, then go through the sign-up procedure again. I created `LewisGaul-staticman`.


### The config file

Back on the server, we need to create a config file for Staticman. With the `NODE_ENV` variable unset, the default is "production"(?).

I created a production config file, based on the sample config:
```bash
cp config.sample.json config.production.json
```

The Staticman documentation simply says:

> Edit the newly-created config file with your GitHub access token, SSH private key and the port to run the server.

So let's look at each of those.


#### GitHub access token

See GitHub's documentation for creating an access token, and copy the new access token into the githubToken property in the config file.


#### RSA Key

Wait, I thought you said SSH key? I'll explain.

The 'Requirements' section of the Staticman docs says you need an SSH key, and links to GitHub's documentation on creating an RSA key and associating it to your GitHub account so that it can be used for authentication when connecting to GitHub via SSH. But Staticman doesn't use it for that at all - Staticman only uses this key for encryption, nothing else.

Rather than following GitHub's documentation for creating the key, note that Staticman expects the key to be in PEM format. So just create an RSA key in PEM format with:

```bash
openssl genrsa -out key.pem
```

Take the contents of `key.pem`, remove all line breaks (or replace them with \n - it doesn't really matter which) and paste that into the rsaPrivateKey property of your config file.


#### Port

The port you choose is up to you. I chose to use Apache on my server, so I chose port 8642.


#### Last steps

At this point you should be able to run `npm start` and it should work! If so, hit `Ctrl+c`. There's more work to do.

Since I will be using Apache as a proxy, I want to prevent the outside world from directly accessing Staticman on port 8642, so I edited `server.js` so that it would only listen on the local loopback IP (`127.0.0.1`) - see my repo fork.

```javascript
this.instance = this.server.listen(config.get('port'), '127.0.0.1', () => {
```


## Setting up Apache

### Acmetool

```
$crontab -l
@weekly sudo /usr/local/bin/acmetool reconcile --batch
```


### Moving Minegauler

```
$cat conf.d/minegauler.conf
<VirtualHost *:80>
  ServerName minegauler.lewisgaul.co.uk
  ProxyPreserveHost On

  ErrorLog logs/minegauler.error.log
  CustomLog logs/minegauler.access.log combined

  ProxyPass /.well-known/ !
  ProxyPass / http://localhost:8080/
  ProxyPassReverse / http://localhost:8080/

  Alias "/.well-known/acme-challenge/" "/var/run/acme/acme-challenge/"
  <Directory "/var/run/acme/acme-challenge">
    AllowOverride None
    Options None

    # If using Apache 2.4+
    #Require all granted

    # If using Apache 2.2 and lower
    Order allow,deny
    Allow from all
  </Directory>

</VirtualHost>
```

```
$cat conf.d/minegauler.ssl.conf
<VirtualHost *:443>
  ServerName minegauler.lewisgaul.co.uk
  ProxyPreserveHost On

  ErrorLog logs/minegauler.error.log
  CustomLog logs/minegauler.access.log combined

  ProxyPass / http://localhost:8080/
  ProxyPassReverse / http://localhost:8080/

  SSLEngine on

  SSLCertificateFile      /var/lib/acme/live/minegauler.lewisgaul.co.uk/cert
  SSLCertificateKeyFile   /var/lib/acme/live/minegauler.lewisgaul.co.uk/privkey
  SSLCertificateChainFile /var/lib/acme/live/minegauler.lewisgaul.co.uk/chain
</VirtualHost>
```


### Staticman

```
$cat conf.d/staticman.conf
<VirtualHost *:80>
  ServerName comments.lewisgaul.co.uk

  ErrorLog logs/staticman.error.log
  CustomLog logs/staticman.access.log combined

  DocumentRoot /var/www/html/
  ProxyPass /.well-known/ !
  ProxyPass /v2/connect !
  ProxyPass / http://localhost:8642/
  ProxyPassReverse / http://localhost:8642/

  Alias "/.well-known/acme-challenge/" "/var/run/acme/acme-challenge/"
  <Directory "/var/run/acme/acme-challenge">
    AllowOverride None
    Options None

    # If using Apache 2.4+
    #Require all granted

    # If using Apache 2.2 and lower
    Order allow,deny
    Allow from all
  </Directory>

</VirtualHost>
```

```
$cat /etc/httpd/conf.d/staticman.ssl.conf
<VirtualHost *:443>
  ServerName comments.lewisgaul.co.uk

  ErrorLog  logs/staticman.error.log
  CustomLog logs/staticman.access.log combined

  DocumentRoot /var/www/html/
  ProxyPass /.well-known/ !
  ProxyPass /v2/connect !
  ProxyPass / http://localhost:8642/
  ProxyPassReverse / http://localhost:8642/

  SSLEngine on

  SSLCertificateFile      /var/lib/acme/live/comments.lewisgaul.co.uk/cert
  SSLCertificateKeyFile   /var/lib/acme/live/comments.lewisgaul.co.uk/privkey
  SSLCertificateChainFile /var/lib/acme/live/comments.lewisgaul.co.uk/chain
</VirtualHost>
```
