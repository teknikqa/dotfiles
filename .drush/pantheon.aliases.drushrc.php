<?php
  /**
   * Pantheon drush alias file, to be placed in your ~/.drush directory or the aliases
   * directory of your local Drush home. Once it's in place, clear drush cache:
   *
   * drush cc drush
   *
   * To see all your available aliases:
   *
   * drush sa
   *
   * See http://helpdesk.getpantheon.com/customer/portal/articles/411388 for details.
   */
  $aliases['cirs.*'] = array(
    'uri' => '${env-name}-cirs.pantheonsite.io',
    'remote-host' => 'appserver.${env-name}.607e0001-47b9-40a0-a620-c7c362c4bc45.drush.in',
    'remote-user' => '${env-name}.607e0001-47b9-40a0-a620-c7c362c4bc45',
    'ssh-options' => '-p 2222 -o "AddressFamily inet"',
    'path-aliases' => array(
      '%files' => 'files',
     ),
  );

  $aliases['guq-epe.*'] = array(
    'uri' => '${env-name}-guq-epe.pantheonsite.io',
    'remote-host' => 'appserver.${env-name}.781a276f-fe2b-4970-8908-a76a85577011.drush.in',
    'remote-user' => '${env-name}.781a276f-fe2b-4970-8908-a76a85577011',
    'ssh-options' => '-p 2222 -o "AddressFamily inet"',
    'path-aliases' => array(
      '%files' => 'files',
     ),
  );

  $aliases['guq-sites.*'] = array(
    'uri' => '${env-name}-guq-sites.pantheonsite.io',
    'remote-host' => 'appserver.${env-name}.6d3c3b21-4086-487c-b27f-b80e5fede99c.drush.in',
    'remote-user' => '${env-name}.6d3c3b21-4086-487c-b27f-b80e5fede99c',
    'ssh-options' => '-p 2222 -o "AddressFamily inet"',
    'path-aliases' => array(
      '%files' => 'files',
     ),
  );

  $aliases['guq1.*'] = array(
    'uri' => '${env-name}-guq1.pantheonsite.io',
    'remote-host' => 'appserver.${env-name}.b5cc8923-cbbd-4366-b159-7ccb0a853e2a.drush.in',
    'remote-user' => '${env-name}.b5cc8923-cbbd-4366-b159-7ccb0a853e2a',
    'ssh-options' => '-p 2222 -o "AddressFamily inet"',
    'path-aliases' => array(
      '%files' => 'files',
     ),
  );

