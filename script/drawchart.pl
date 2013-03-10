#!/usr/bin/env perl
use strict;

sub versionify {
    my $v = shift;
    $v =~ /^5\.(\d{3})(\d{3})/
      and return join '.', 5, $1+0, $2+0;
}

my %versions;

while (<>) {
    my @line = split / /, $_;
    my $perl = $line[12];
    if ($perl =~ /^perl\/(5\.\d{6})"$/) {
        $versions{$1}++;
    }
}

my $js_data = join ",\n", map { "[ '@{[versionify($_)]}', $versions{$_} ]" } sort keys %versions;

print <<HTML;
<html>
    <head>
      <script type="text/javascript" src="https://www.google.com/jsapi"></script>
      <script type="text/javascript">
      google.load("visualization", "1", {packages:["corechart"]});
      google.setOnLoadCallback(drawChart);
      function drawChart() {
        var data = google.visualization.arrayToDataTable([
          ['Version', 'Requests'],
          $js_data
        ]);

        var options = {
          title: 'Perl versions used with cpanm'
        };

        var chart = new google.visualization.PieChart(document.getElementById('chart_div'));
        chart.draw(data, options);
      }
    </script>
    </head>
  <body>
    <div id="chart_div" style="width: 900px; height: 500px;"></div>
  </body>
</html>
HTML