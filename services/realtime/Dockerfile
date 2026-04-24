FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20 AS build

RUN apk add --no-cache build-base git

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
COPY config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

COPY lib ./lib
RUN mix compile
RUN mix release

FROM alpine:3.20 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app
ENV MIX_ENV=prod

COPY --from=build /app/_build/prod/rel/relay_chat_realtime ./

CMD ["bin/relay_chat_realtime", "start"]
