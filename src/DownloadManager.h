#pragma once
#ifndef SM_DOWNMANAGER

#define SM_DOWNMANAGER

#if !defined(WITHOUT_NETWORKING)




#include "global.h"
#include "CommandLineActions.h"
#include "RageFile.h"
#include "HighScore.h"
#include "ScreenManager.h"
#include "RageFileManager.h"
#include "curl/curl.h"
#include "Difficulty.h"





class DownloadablePack;

class ProgressData {
public:
	curl_off_t total{ 0 }; //total bytes
	curl_off_t downloaded{ 0 }; //bytes downloaded
	float time{ 0 };//seconds passed
};

class RageFileWrapper {
public:
	RageFile file;
	size_t bytes{ 0 };
	bool stop{ false };
};

class Download {
public:
	Download(string url);
	~Download();
	void Install();
	void Update(float fDeltaSeconds);
	void Failed();
	string StartMessage() { return "Downloading file " + m_TempFileName + " from " + m_Url; };
	string Status() {
		return m_TempFileName + "\n" + speed + " KB/s\n" +
			"Downloaded " + to_string((progress.downloaded > 0 ? progress.downloaded : p_RFWrapper.bytes) / 1024) + (progress.total > 0 ? "/" + to_string(progress.total / 1024) + " (KB)" : "");
	}
	CURL* handle{nullptr};
	int running{1};
	ProgressData progress;
	string speed{""};
	curl_off_t downloadedAtLastUpdate {0};
	curl_off_t lastUpdateDone{ 0 };
	string m_Url{""};
	RageFileWrapper p_RFWrapper;
	DownloadablePack* p_Pack{nullptr};
	string m_TempFileName{""};
	// Lua
	void PushSelf(lua_State *L);
protected:
	string MakeTempFileName(string s);
};

class DownloadablePack {
public:
	string name{ "" };
	size_t size{ 0 };
	int id{ 0 };
	float avgDifficulty{ 0 };
	string url{ "" };
	bool downloading{ false };
	// Lua
	void PushSelf(lua_State *L);
};

class HTTPRequest {
public:
	HTTPRequest(CURL * h, function<void(HTTPRequest&)> done = [](HTTPRequest& req) {return; },
		curl_httppost* postform = nullptr, function<void(HTTPRequest&)> fail = [](HTTPRequest& req) {return; }):
		handle(h), form(postform), Done(done), Failed(fail) {};
	CURL * handle{ nullptr };
	curl_httppost* form{ nullptr };
	string result;
	function<void(HTTPRequest&)> Done;
	function<void(HTTPRequest&)> Failed;
};
class OnlineTopScore {
public:
	float wifeScore{ 0.0f };
	string songName;
	float rate{ 0.0f };
	float ssr{ 0.0f };
	float overall{ 0.0f };
	string chartkey;
	string scorekey;
	Difficulty difficulty;
	string steps;
};
class OnlineScore {
public:
	map<Skillset, float> SSRs;
	float rate{ 0.0f };
	float wife{ 0.0f };
	int maxcombo{ 0 };
	int miss{ 0 };
	int bad{ 0 };
	int good{ 0 };
	int great{ 0 };
	int perfect{ 0 };
	int marvelous{ 0 };
	int minehits{ 0 };
	int held{ 0 };
	int letgo{ 0 };
	bool valid{ false };
	bool nocc{ false };
	string username;
	float playerRating{ 0.0f };
	string modifiers;
	DateTime datetime;
	vector<pair<float, float>> replayData;
};
class DownloadManager
{
public:
	DownloadManager();
	~DownloadManager();
	map<string, Download*> downloads; // Active downloads
	vector<HTTPRequest*> HTTPRequests; // Active HTTP requests (async, curlMulti)
	map<string, Download*> finishedDownloads;
	CURLM* mPackHandle{ nullptr }; // Curl multi handle for packs downloads
	CURLM* mHTTPHandle{ nullptr }; // Curl multi handle for httpRequests
	CURLMcode ret;
	int downloadingPacks{ 0 };
	int HTTPRunning{ 0 };
	bool loggingIn{ false }; // Currently logging in (Since it's async, to not try twice)
	bool gameplay{ false }; // Currently in gameplay
	string error{ "" };
	int lastid{ 0 };
	vector<DownloadablePack> downloadablePacks;
	bool reloadPending{ false }; // Song reload pending
	bool CachePackList(string url); // Fill downloadablePacks with GetPackList
	string session{ "" }; // Session cookie content
	string sessionCookie{ "" }; // Entire session cookie string
	string sessionUser{ "" }; // Currently logged in username
	string sessionPass{ "" }; // Currently logged in password
	string lastVersion{""}; // Last version according to server (Or current if non was obtained)
	map<string, vector<OnlineScore>> chartLeaderboards;
	map<Skillset, int> sessionRanks; // Leaderboard ranks for logged in user by skillset
	map<Skillset, double> sessionRatings;
	map<Skillset, vector<OnlineTopScore>> topScores;
	bool LoggedIn();
	void EndSessionIfExists(); //Calls EndSession if logged in
	void EndSession(); //Sends session destroy request
	void StartSession(string user, string pass); //Sends login request if not already logging in
	bool UploadScores(); //Uploads all scores not yet uploaded to current server (Async, 1 request per score)
	vector<DownloadablePack>* GetPackList(string url, bool &result); // Blocking (Not asyn/curlMulti)

	Download* DownloadAndInstallPack(const string &url);
	Download*  DownloadAndInstallPack(DownloadablePack* pack);
	bool UpdateAndIsFinished(float fDeltaSeconds);
	bool UpdatePacksAndIsFinished(float fDeltaSeconds);
	bool UpdateHTTPAndIsFinished(float fDeltaSeconds);
	bool InstallSmzip(const string &sZipFile);

	void UpdateDLSpeed();
	void UpdateDLSpeed(bool gameplay);

	string GetError() { return error; }
	bool Error() { return error == ""; }
	bool EncodeSpaces(string& str);

	void UploadScoreWithReplayData(HighScore* hs);
	void UploadScore(HighScore* hs);

	bool ShouldUploadScores();

	inline void AddSessionCookieToCURL(CURL *curlHandle);
	inline void SetCURLPostToURL(CURL *curlHandle, string url);
	inline void SetCURLURL(CURL *curlHandle, string url);

	void SendRequest(string requestName, vector<pair<string, string>> params, function<void(HTTPRequest&)> done, bool requireLogin = true, bool post = false, bool async = true);
	void RefreshLastVersion(); 
	void RequestChartLeaderBoard(string chartkey);
	void RefreshUserData();
	void RefreshUserRank();
	void RefreshTop25(Skillset ss);
	OnlineTopScore GetTopSkillsetScore(unsigned int rank, Skillset ss, bool &result);
	float GetSkillsetRating(Skillset ss);
	int GetSkillsetRank(Skillset ss);

	// most recent single score upload result -mina
	RString mostrecentresult = "";

	// Lua
	void PushSelf(lua_State *L);
};

extern shared_ptr<DownloadManager> DLMAN;

#endif

#endif