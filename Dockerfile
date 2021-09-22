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
FROM ruby:2.6.8-alpine3.14 AS builder

WORKDIR /app

RUN apk add --update --no-cache git bash curl make gcc libc-dev tzdata g++ npm

# copy app
COPY . /app

# install gems
RUN bundle install --jobs 20 --retry 5 --deployment --without development test

# build the UI
RUN cd dashboard && npm install --no-optional && npm rebuild node-sass && node_modules/.bin/gulp release

##############################################################
# Stage: final
FROM ruby:2.6.8-alpine3.14

LABEL org="Appvia Ltd"
LABEL website="appvia.io"
LABEL maintainer="marcin.ciszak@appvia.io"
LABEL source="https://github.com/appvia/krane"

ENV APP_PATH /app

RUN apk add --update --no-cache git bash curl npm yarn

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/linux/amd64/kubectl && \
	chmod +x ./kubectl && \
	mv ./kubectl /usr/local/bin/kubectl

RUN addgroup -g 1000 -S appuser \
 && adduser -u 1000 -S appuser -G appuser

USER 1000

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder --chown=1000:1000 /app $APP_PATH

WORKDIR $APP_PATH

ENV HOME $APP_PATH
ENV PORT 8000
ENV KRANE_ENV production
ENV PATH $APP_PATH/bin:$PATH

ENTRYPOINT ["bin/krane"]
CMD ["report", "--incluster"]
