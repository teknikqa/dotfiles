<?php

/**
 * Drupal VM drush aliases.
 *
 * Ansible managed
 */

$aliases['dev'] = array(
  'uri' => 'dev.epe.test',
  'root' => '/var/www/epevm/web',
  'remote-host' => 'dev.epe.test',
  'remote-user' => 'vagrant',
  'ssh-options' => '-o "SendEnv PHP_IDE_CONFIG PHP_OPTIONS XDEBUG_CONFIG" -o PasswordAuthentication=no -i "' . (getenv('VAGRANT_HOME') ?: drush_server_home() . '/.vagrant.d') . '/insecure_private_key"',
  'path-aliases' => array(
    '%drush-script' => 'drush',
  ),
);

