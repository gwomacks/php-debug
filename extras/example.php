<?php
  ## This is a nice example file for using Xdebug
  ## To begin debugging, do the following
  ## 1. Start the debugger (ctrl + alt + d, or from the php-debug packages menu)
  ## 2. Move your curser to line 30
  ## 3. Set a breakpoint (alt + F9, or from the php-debug packages menu)
  ## 4. Run the script
  ##    - if you have debug.remote_autostart set to true, it should just work
  ##    - otherwise, use an xdebug browser extension to start the script with xdebug enabled
  ##    - or,
  xdebug_break();
  $i = 1;

  class ResursivePrinter
  {

    var $member;
    function __construct() {
      $this->member = array('kittens' => 'doom');
    }

    function recursivePrintNumber($limit, $cur = 0) {

      print $cur."\n";
      if($cur < $limit)
        $this->recursivePrintNumber($limit, $cur+1);
    }
  }

  $rs = new ResursivePrinter();
  $rs->recursivePrintNumber(64); # Try setting a breakpoint on this line

  print "finished";
