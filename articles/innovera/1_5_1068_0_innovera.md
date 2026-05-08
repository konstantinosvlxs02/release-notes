# Release Notes - Version 1.5.1068.0

This document describes the **new features**, *bug fixes*, and breaking changes introduced in version 1.5.1068.0.

## New Features

- Improved PDF export with embedded fonts

- Dark mode support across all views

- New REST API endpoints for batch processing

- Performance improvements: 40% faster startup time

## Bug Fixes

- Fixed crash on startup when config file is missing

- Resolved memory leak in background sync service

- Corrected date formatting for non-US locales

- Fixed incorrect totals in summary reports

## Breaking Changes

The **LegacyAuthProvider** class has been removed. Migrate to **OAuthProvider** before upgrading.

## Compatibility Matrix

|               |                 |                             |
|---------------|-----------------|-----------------------------|
| **Component** | **Min Version** | **Notes**                   |
| .NET Runtime  | 6.0             | Required for all features   |
| SQL Server    | 2019            | 2017 works with limitations |
| Windows       | 10 (21H2)       | Server 2019 also supported  |

## Known Limitations

### Performance

Batch exports exceeding 500 records may experience slowdowns on systems with less than 8 GB RAM.

### Localization

Right-to-left language support is experimental in this release.

## Additional Notes

For full migration steps, refer to the **official upgrade guide**. Support for version 1.4.x ends on *December 31, 2026*.
