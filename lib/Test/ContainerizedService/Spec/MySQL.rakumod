use v6.d;
use Test::ContainerizedService::Spec;

class Test::ContainerizedService::Spec::MySQL does Test::ContainerizedService::Spec {
    has Int $!port = self.generate-port;
    has Str $!password = self.generate-secret;

    method docker-container(--> Str) { 'mysql' }

    method default-docker-tag(--> Str) { 'latest' }

    method docker-options(--> Positional) {
        [
            '-e', "MYSQL_ROOT_PASSWORD=$!password",
            '-e', 'MYSQL_DATABASE=testdb',
            '-e', 'MYSQL_ROOT_HOST=%',
            '-p', "127.0.0.1:$!port:3306"
        ]
    }

    method docker-command-and-arguments(--> Positional) {
        [
            # The container by default does not allow for connections from outside. Add an
            # instruction to enable this.
            'bash', '-c', q{sed -i 's/\[mysqld\]/[mysqld]\nbind-address = 0.0.0.0/' /etc/my.cnf ; cat /etc/my.cnf > /dev/stderr ; /entrypoint.sh mysqld}
        ]
    }

    method ready(Str :$name --> Promise) {
        self.ready-by-connectability('127.0.0.1', $!port)
    }

    method service-data(--> Associative) {
        {
            :host<127.0.0.1>, :$!port, :user<root>, :$!password, :database<testdb>
        }
    }
}
