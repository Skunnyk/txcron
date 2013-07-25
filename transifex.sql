--
-- Database: `transifex`
--

-- --------------------------------------------------------

--
-- Table structure for table `credits`
--

CREATE TABLE IF NOT EXISTS `credits` (
  `identity` varchar(255) NOT NULL DEFAULT '',
  `lang_code` varchar(10) NOT NULL DEFAULT '',
  `n_commits` int(11) NOT NULL DEFAULT '1',
  `last_commit` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identity`,`lang_code`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

