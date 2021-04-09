# duo-client

This project automates [Duo Security](https://duo.com/product/multi-factor-authentication-mfa/two-factor-authentication-2fa) online two-factor challenges. It was inspired by a [Duo OTP generator](https://github.com/rcslab/duo-cli) that I found a few days ago. I wanted to take that project a few steps further by completely automating the Duo authentication process. I accomplish this by sending raw HTTPS requests to endpoints of Duo's web-api. A simplified flow would typically look like this:

1. Start by **obtaining the parameters from the Duo iframe in your online service.**
2. Fetch the Duo iframe from the provided parameters
3. Send an HOTP code that you can generate [however you like](https://github.com/rcslab/duo-cli)
4. Return the response key and parent URL where it should be sent.
5. Finish by **sending the response key back to your online service.**

I'm using this project to automate signing into the the SSO portal used at my school and you might be able to do the same. Check out the usage instructions for details. I'll probably add more documentation to this project when I get a chance. Please also note that this API is brand new and will likely be subject to significant changes. It's also somewhat quick-and-dirty right now with very limited error handling so please use at your own risk.

## Usage

The CLI part of this project is really not intended to be used directly. It's more-so just there to demonstrate how some code using `Duo::Client` might work. Either way, when looking/parsing through the Duo page on your online service, you should see an iframe tag that looks like this:

```html
<iframe id="duo_iframe"
        frameborder="0"
        data-post-argument="nameOfTheDuoResponsePostParameter"
        data-host="api-SOMEAPI.duosecurity.com"
        data-sig-request="TX|some1stlongalphanumericcode|some2ndlongalphanumericcode:APP|some3rdlongalphanumericcode|some4thlongalphanumericcode">
</iframe>
```

It's worth noting that these parameters might not be in the HTML. For more information on how this might be implemented (and for unobfuscated code), check out the official [duo_web_sdk repo](https://github.com/duosecurity/duo_web_sdk). Once you've figured out these parameters, you can use the `Duo::Client` API to send those requests and take care of all the stuff that would normally happen in that iframe. For details on how to do this, please refer to [duo-cli.cr](https://git.lyczak.net/del/duo-client/src/commit/3bd94128b1b292a615d49f3826c2147c863d1132/src/duo-cli.cr#L26).
