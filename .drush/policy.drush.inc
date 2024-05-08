<?php

/**
 * @file
 * Drush policies to restrict what is allowed for certain drush commands.
 */

/**
 * Prevent production databases from being overwritten using drush sql-sync.
 */
function drush_policy_sql_sync_validate($source = NULL, $destination = NULL) {
  if ((strpos($destination, 'prod') !== FALSE) ||
      (strpos($destination, 'live') !== FALSE)) {
    return drush_set_error('POLICY_DENY', dt('You cannot overwrite a production database.'));
  }
}

/**
 * Prevent production files from being overwritten using drush core-rsync.
 */
function drush_policy_core_rsync_validate($source = NULL, $destination = NULL) {
  if ((strpos($destination, 'prod') !== FALSE) ||
      (strpos($destination, 'live') !== FALSE)) {
    return drush_set_error('POLICY_DENY', dt('You cannot rsync to a production site.'));
  }
}
