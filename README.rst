=======================================
Splash - A javascript rendering service
=======================================

This is a fork from this github repository: https://github.com/scrapinghub/splash
It has been modified in order to deploy splash docker image on Heroku (https://dashboard.heroku.com):


- Removed command EXPOSE on Dockerfile because it's not supported by Heroku
- Replaced ENTRYPOINT by CMD command. The CMD command executes a bash script called "run.sh" (https://github.com/Shokesu/splash/blob/master/run.sh) which runs the splash server with python

- Added the option --port=$PORT when running the splash server, to listen at the port specified by Heroku instead of the default (8050)

That's all.

You can test docker image locally. When running the image, you must pass the environment variable "PORT"




