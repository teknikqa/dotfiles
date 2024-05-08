<?php

/**
 * @file
 * drushrc.php
 */

/**
 * Open link in specific browser.
 *
 * In case you do web development in a specific browser and all other browsing
 * in your default browser, this will force drush to open links in the browser
 * that you specify.
 */
$command_specific['user-login'] = array('browser' => 'open -a FirefoxDeveloperEdition');
// Use this for Google Chrome Canary.
// $command_specific['user-login'] = array('browser' => 'open -a  Google\ Chrome\ Canary');

$options["include"][] = drush_server_home() . "/.drush/pantheon/drush8";