use v6.d;
use Test::ContainerizedService::Spec;

class Test::ContainerizedService::Spec::Redis does Test::ContainerizedService::Spec {
    has Int $!port = self.generate-port;

    method docker-container(--> Str) { 'redis' }

    method default-docker-tag(--> Str) { 'latest' }

    method docker-options(--> Positional) {
        [
            '-p', "127.0.0.1:$!port:6379"
        ]
    }

    method ready(Str :$name --> Promise) {
        self.ready-by-connectability('127.0.0.1', $!port)
    }

    method service-data(--> Associative) {
        { :host<127.0.0.1>, :$!port }
    }
}
