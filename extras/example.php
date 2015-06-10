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

  class RecursivePrinter
  {

    var $member;
    var $float = 9.9;
    function __construct() {
      $this->member = array('key' => 'doom');

      for($i = 0; $i < 10; $i++)
        $this->member = array('key' => $this->member);
    }

    function recursivePrintNumber($limit, $cur = 0) {

      print $cur."\n";
      if($cur < $limit)
        $this->recursivePrintNumber($limit, $cur+1);
    }
  }

  $rs = new RecursivePrinter();
  $rs->recursivePrintNumber(64); # Try setting a breakpoint on this line
  throw new Exception();
  print "finished";
