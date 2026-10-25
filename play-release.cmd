@echo off
rem SchoolSift Google Play release. See docs\PLAY_RELEASE.md
rem   play-release.cmd check | internal | production | metadata   [key:value ...]
setlocal
chcp 65001 >nul
if "%~1"=="" (
  echo Usage: play-release.cmd check ^| internal ^| production ^| metadata  [version_code:N] [version_name:x.y.z]
  exit /b 2
)
where bundle >nul 2>nul || set "PATH=C:\Ruby33-x64\bin;%PATH%"
where bundle >nul 2>nul || (
  echo Ruby/Bundler not found. Install: winget install RubyInstallerTeam.RubyWithDevKit.3.3 ; then: cd app\android ^&^& bundle install
  exit /b 1
)
cd /d "%~dp0app\android"
bundle exec fastlane android %*
