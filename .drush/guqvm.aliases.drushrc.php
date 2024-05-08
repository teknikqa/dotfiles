<?php

/**
 * Drupal VM drush aliases.
 *
 * Ansible managed
 */

$aliases['dev'] = array(
  'uri' => 'dev.guq.test',
  'root' => '/var/www/guqvm/web',
  'remote-host' => 'dev.guq.test',
  'remote-user' => 'vagrant',
  'ssh-options' => '-o "SendEnv PHP_IDE_CONFIG PHP_OPTIONS XDEBUG_CONFIG" -o PasswordAuthentication=no -i "' . (getenv('VAGRANT_HOME') ?: drush_server_home() . '/.vagrant.d') . '/insecure_private_key"',
  'path-aliases' => array(
    '%drush-script' => 'drush',
  ),
);

