#! /usr/bin/env perl

use Device::Modbus::RTU::Client;
use Data::Dumper;
use strict;
use warnings;
use v5.10;
use Net::MQTT::Simple;

# Allow unencrypted connection with credentials
$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;

my $debug     = 0;
my $drehzahl  = 0;
my $watertemp = 0;
my $oiltemp   = 0;
my $oildruck  = 0;
my $battery   = 0;
my $fuel      = 0;
my $datum     = 0;
my $zeit      = 0;
my $frequenz  = 0;
my @Spannung  = ();
my @Strom     = ();
my @Energie   = ();
my $Laufzeit  = 0;
my $SumEnergie= 0;
my $Starts    = 0;
my $runtime   = 3585;
my $req;
my @index = (0 .. 101);

my $client = Device::Modbus::RTU::Client->new(
    port     => '/dev/serial0',
    baudrate => 19200,
    #databits => 8,
    parity   => 'none',
    #stopbits => 1,
    timeout  => 1,
);


my $mqtt = Net::MQTT::Simple->new("Servername or IP_Address");
$mqtt->login("username","password");

while($runtime > 5) {

$req = $client->read_holding_registers(
    unit     => 16,
    address  => 0x1000,
    quantity => 0x66,
);

say "->" . Dumper $req if($debug == 1);
$client->send_request($req);

my $resp = $client->receive_response;
say "<-" . Dumper $resp if($debug == 1);

my $werte = $resp->values if $resp->success;
say "Werte:\n" . Dumper $werte if($debug == 1);

@index = (0 .. 101);
foreach(@index){
    print "Wert".$_.": ".$resp->values->[$_]."\n";
}

$drehzahl  = $resp->values->[0];
$battery   = $resp->values->[1]/10;
#$wert2    = $resp->values->[2]; #Spannung D+
$watertemp = $resp->values->[3];
$oildruck  = $resp->values->[4]/100;
$fuel      = $resp->values->[5];
$oiltemp   = $resp->values->[6];
$datum     = $resp->values->[7];
$zeit      = $resp->values->[8];
$frequenz  = $resp->values->[9];
$Starts    = $resp->values->[53];
$Laufzeit  = $resp->values->[55]/10;
$SumEnergie= $resp->values->[62];
#$Laufzeit = $resp->values->[62];
#$Laufzeit = $resp->values->[62];

@index = (10 .. 15);
foreach(@index){
    push (@Spannung, $resp->values->[$_]);
}

@index = (16 .. 19);
foreach(@index){
    push (@Strom, $resp->values->[$_]);
}

@index = (20 .. 27);
foreach(@index){
    push (@Energie, $resp->values->[$_]);
}

print "\n";
print "Uhrzeit:      ".$zeit      ." \n";
print "Drehzahl:     ".$drehzahl  ." rpm\n";
print "Batterie:     ".$battery   ." V\n";
print "Wassertemp:   ".$watertemp ." °C\n";
print "Oiltemp:      ".$oiltemp   ." °C\n";
print "Oildruck:     ".$oildruck  ." Mpa\n";
print "Tank:         ".$fuel      ." %\n";
print "Frequenz:     ".$frequenz  ." Hz\n";
print "Spannungen:   "."@Spannung"." Vrms\n";
print "Stromwerte:   "."@Strom"   ." A\n";
print "Energiewerte: "."@Energie" ." kW\n";
print "Energie:      ".$SumEnergie." kwh\n";
print "Laufzeit:     ".$Laufzeit  ." h\n";
print "Starts:       ".$Starts    ." \n";

    $mqtt->publish("GEN/status/1/rpm"       => $drehzahl);
    $mqtt->publish("GEN/status/1/battvolt"  => $battery);
    $mqtt->publish("GEN/status/1/watertemp" => $watertemp);
    $mqtt->publish("GEN/status/1/oiltemp"   => $oiltemp);
    $mqtt->publish("GEN/status/1/oilpress"  => $oildruck);
    $mqtt->publish("GEN/status/1/fuel"      => $fuel);
    $mqtt->publish("GEN/status/1/frequency" => $frequenz);
    $mqtt->publish("GEN/status/1/u1"        => $Spannung[0]);
    $mqtt->publish("GEN/status/1/u2"        => $Spannung[1]);
    $mqtt->publish("GEN/status/1/u3"        => $Spannung[2]);
    $mqtt->publish("GEN/status/1/i1"        => $Strom[0]);
    $mqtt->publish("GEN/status/1/i2"        => $Strom[1]);
    $mqtt->publish("GEN/status/1/i3"        => $Strom[2]);
    $mqtt->publish("GEN/status/1/p1"        => $Energie[0]);
    $mqtt->publish("GEN/status/1/p2"        => $Energie[1]);
    $mqtt->publish("GEN/status/1/p3"        => $Energie[2]);
    $mqtt->publish("GEN/status/1/p_sum"     => $SumEnergie);
    $mqtt->publish("GEN/status/1/runhours"  => $Laufzeit);
    $mqtt->publish("GEN/status/1/starts"    => $Starts);

    sleep(5);
    $runtime=$runtime-5;
    @Spannung  = ();
    @Strom     = ();
    @Energie   = ();
    @index     = ();
}
#$mqtt->run(
#    "GEN/status/1/fuel" => SUB {
#	my ($topic, $message) = @_;
#	die "Is full" if $message >= 100;
#    },
#    "#" => sub {
#	my ($topic, $message) = @_;
#	print "[topic] $message\n";
#    },
#);

$mqtt->disconnect();
$client->disconnect;
