<?php

/**
 * Drupal VM drush aliases.
 *
 * Ansible managed
 */

$aliases['dev'] = array(
  'uri' => 'dev.guqd8.test',
  'root' => '/var/www/guqd8vm/web',
  'remote-host' => 'dev.guqd8.test',
  'remote-user' => 'vagrant',
  'ssh-options' => '-o "SendEnv PHP_IDE_CONFIG PHP_OPTIONS XDEBUG_CONFIG" -o PasswordAuthentication=no -i "' . (getenv('VAGRANT_HOME') ?: drush_server_home() . '/.vagrant.d') . '/insecure_private_key"',
  'path-aliases' => array(
    '%drush-script' => '/var/www/guqd8vm/vendor/drush/drush/drush',
  ),
);

$aliases['dev'] = array(
  'uri' => 'dev.cirs.guqd8.test',
  'root' => '/var/www/guqd8vm/web',
  'remote-host' => 'dev.cirs.guqd8.test',
  'remote-user' => 'vagrant',
  'ssh-options' => '-o "SendEnv PHP_IDE_CONFIG PHP_OPTIONS XDEBUG_CONFIG" -o PasswordAuthentication=no -i "' . (getenv('VAGRANT_HOME') ?: drush_server_home() . '/.vagrant.d') . '/insecure_private_key"',
  'path-aliases' => array(
    '%drush-script' => '/var/www/guqd8vm/vendor/drush/drush/drush',
  ),
);

$aliases['dev'] = array(
  'uri' => 'dev.cee.guqd8.test',
  'root' => '/var/www/guqd8vm/web',
  'remote-host' => 'dev.cee.guqd8.test',
  'remote-user' => 'vagrant',
  'ssh-options' => '-o "SendEnv PHP_IDE_CONFIG PHP_OPTIONS XDEBUG_CONFIG" -o PasswordAuthentication=no -i "' . (getenv('VAGRANT_HOME') ?: drush_server_home() . '/.vagrant.d') . '/insecure_private_key"',
  'path-aliases' => array(
    '%drush-script' => '/var/www/guqd8vm/vendor/drush/drush/drush',
  ),
);

