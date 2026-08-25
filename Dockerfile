# Copyright 2020 Appvia Ltd <info@appvia.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


##############################################################
# Stage: dashboard -- build the UI with Vite
#
# Only the dashboard directory is copied, so a change to the Ruby app does not
# invalidate the npm install layer.
FROM node:22-alpine AS dashboard

WORKDIR /dashboard

COPY dashboard/package.json dashboard/package-lock.json ./
RUN npm ci

COPY dashboard/ ./
RUN npm run build

##############################################################
# Stage: gems
FROM ruby:3.2.2-alpine3.16 AS gems

WORKDIR /app

RUN apk add --update --no-cache git bash make gcc libc-dev g++

COPY Gemfile Gemfile.lock krane.gemspec ./
COPY lib/krane/version.rb lib/krane/version.rb

# Install into the image's gem home rather than the app's vendor directory, so
# the final stage can take the gems without taking a copy of the app with them.
ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=true

RUN gem install bundler --no-document -v $(cat Gemfile.lock | tail -1 | tr -d " ") \
    && bundle install --jobs 20 --retry 5

##############################################################
# Stage: final
FROM ruby:3.2.2-alpine3.16

LABEL org="Appvia Ltd"
LABEL website="appvia.io"
LABEL maintainer="marcin.ciszak@appvia.io"
LABEL source="https://github.com/appvia/krane"

ENV APP_PATH /app

# No npm or yarn: the dashboard is static files served by Ruby.
RUN apk add --update --no-cache git bash curl

ENV KUBECTL_VERSION="1.23.0"
ENV KUBECTL_BINARY_URL=https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl

RUN curl -sL -o /usr/bin/kubectl ${KUBECTL_BINARY_URL} && chmod +x /usr/bin/kubectl

RUN addgroup -g 1000 -S appuser \
    && adduser -u 1000 -S appuser -G appuser

# WORKDIR creates root-owned dirs regardless of USER (classic builder) - the
# app needs to write $APP_PATH/cache at runtime
RUN mkdir -p $APP_PATH/cache && chown -R 1000:1000 $APP_PATH

USER 1000

ENV BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_DEPLOYMENT=true

COPY --from=gems /usr/local/bundle/ /usr/local/bundle/

WORKDIR $APP_PATH

# Only what the app runs from: no node_modules, no dashboard sources.
COPY --chown=1000:1000 Gemfile Gemfile.lock krane.gemspec $APP_PATH/
COPY --chown=1000:1000 bin $APP_PATH/bin
COPY --chown=1000:1000 lib $APP_PATH/lib
COPY --chown=1000:1000 config $APP_PATH/config
COPY --from=dashboard --chown=1000:1000 /dashboard/compiled $APP_PATH/dashboard/compiled

ENV HOME $APP_PATH
ENV PORT 8000
ENV KRANE_ENV production
ENV PATH $APP_PATH/bin:$PATH

ENTRYPOINT ["bin/krane"]
CMD ["report", "--incluster"]
