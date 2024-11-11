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
# Stage: builder
FROM ruby:3.2.2-alpine3.16 AS builder

WORKDIR /app

RUN apk add --update --no-cache git bash curl make gcc libc-dev tzdata g++ npm

# copy app
COPY . /app

# install bundler
RUN gem install bundler --no-document -v $(cat Gemfile.lock | tail -1 | tr -d " ")

# install gems
RUN bundle config set deployment 'true'
RUN bundle config set without 'development test'
RUN bundle install --jobs 20 --retry 5

# build the dashboard elements
RUN cd dashboard && npm install --omit=optional --omit=dev && npm audit fix && npm rebuild node-sass && npm install -g sass-migrator && sass-migrator division **/*.scss && rm -rf ./compiled && node_modules/.bin/gulp build

##############################################################
# Stage: jekyll -- generate dashboard html files
FROM jekyll/jekyll:4.2.0 AS jekyll

WORKDIR /app

COPY --from=builder --chown=jekyll:jekyll /app /app

RUN cd dashboard && jekyll build --trace -s ./src/html -d ./tmp && cp ./tmp/*.html ./compiled && rm -rf ./tmp

##############################################################
# Stage: final
FROM ruby:3.2.2-alpine3.16

LABEL org="Appvia Ltd"
LABEL website="appvia.io"
LABEL maintainer="marcin.ciszak@appvia.io"
LABEL source="https://github.com/appvia/krane"

ENV APP_PATH /app

RUN apk add --update --no-cache git bash curl npm yarn

ENV KUBECTL_VERSION="1.23.0"
ENV KUBECTL_BINARY_URL=https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl

RUN curl -sL -o /usr/bin/kubectl ${KUBECTL_BINARY_URL} && chmod +x /usr/bin/kubectl

RUN addgroup -g 1000 -S appuser \
    && adduser -u 1000 -S appuser -G appuser

USER 1000

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=jekyll --chown=1000:1000 /app $APP_PATH

WORKDIR $APP_PATH

ENV HOME $APP_PATH
ENV PORT 8000
ENV KRANE_ENV production
ENV PATH $APP_PATH/bin:$PATH

ENTRYPOINT ["bin/krane"]
CMD ["report", "--incluster"]

