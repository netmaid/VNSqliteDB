Pod::Spec.new do |s|
  s.name             = "VNSqliteDB"
  s.version          = "0.1.0"
  s.summary          = "The Objective-C wrapper class for SqliteDB"
  s.description      = <<-DESC
                         This wrapper class is easy to use for c function of SqliteDB.
                          The class of VNSqliteDB is simple and intuitive moreover less code,
                          under 1k lines of code.
                       DESC

  s.homepage         = "https://github.com/netmaid/VNSqliteDB"
  s.license          = { :type => "MIT", :file => "LICENSE" }
  s.author           = "Chungmin Ahn"
  s.source           = { :git => "https://github.com/netmaid/VNSqliteDB.git", :tag => "v#{s.version}" }

  s.platform     = :ios, '6.0'
  s.requires_arc = true

  s.source_files = 'VNSqliteDB/**/*.{h,m,mm}'
  s.public_header_files = 'VNSqliteDB/**/*.h'
  s.libraries = 'sqlite3'
end
