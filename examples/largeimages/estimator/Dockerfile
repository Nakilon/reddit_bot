FROM ruby:2.6-alpine

# based on felixbuenemann/vips-alpine and codechimpio/vips-alpine
# TODO: also take a look at https://github.com/jcupitt/docker-builds/blob/master/ruby-vips-alpine/Dockerfile
# we don't install from checkouted folder, because we want to test that the gem is available at Rubygems

ARG VIPS_VERSION=8.9.2
RUN set -ex -o pipefail && \
    wget -O- https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.gz | tar xzC /tmp && \
    apk update && apk upgrade && apk add --no-cache \
      zlib libxml2 glib-dev gobject-introspection \
      libjpeg-turbo libexif lcms2 fftw libpng \
      orc libgsf openexr && \
    apk add --no-cache --virtual common-dependencies build-base && \
    apk add --no-cache --virtual vips-dependencies \
      zlib-dev libxml2-dev gobject-introspection-dev \
      libjpeg-turbo-dev libexif-dev lcms2-dev fftw-dev libpng-dev \
      orc-dev libgsf-dev openexr-dev && \
    cd /tmp/vips-${VIPS_VERSION} && ./configure --prefix=/usr \
                                                --without-python \
                                                --without-gsf \
                                                --without-tiff \
                                                --enable-debug=no \
                                                --disable-static \
                                                --disable-dependency-tracking \
                                                --enable-silent-rules && \
    make -s install-strip && cd $OLDPWD && rm -rf /tmp/vips-${VIPS_VERSION} && apk del --purge vips-dependencies && \
    apk add --no-cache --virtual ffi-dependencies libffi-dev

# RUN apk del --purge common-dependencies
RUN gem install ruby-vips -v '=2.0.17' && apk del --purge ffi-dependencies

WORKDIR /app
RUN apk add curl && gem install bundler
ENV BUNDLE_FROZEN=true
COPY ./function/Gemfile ./function/Gemfile.lock ./
RUN bundle install
COPY ./function/app.rb ./function/common.rb ./function/all.yaml ./
CMD ["bundle", "exec", "functions-framework-ruby", "--target", "estimator"]

# $ docker build -t gcr.io/nakilonpro/estimator --progress plain -f Dockerfile .
# $ docker run --rm -ti -p 8080:8080 gcr.io/nakilonpro/estimator
# $ curl http://localhost:8080/estimator -d "$(printf 'https://i.redd.it/sxu2yg3jwoo61.jpg' | base64)"
# $ docker exec -ti 60865b346feb cat /proc/1/status | grep VmPeak
# $ docker push gcr.io/nakilonpro/estimator
