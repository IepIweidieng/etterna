
#ifndef SM_DOWNMANAGER

#define SM_DOWNMANAGER

#if !defined(WITHOUT_NETWORKING)




#include "global.h"
#include "CommandLineActions.h"
#include "RageFile.h"
#include "ScreenManager.h"
#include "RageFileManager.h"
#include "curl/curl.h"





class DownloadablePack;

class ProgressData {
public:
	curl_off_t total = 0; //total bytes
	curl_off_t downloaded = 0; //bytes downloaded
	float time = 0;//seconds passed
};

class WriteThis {
public:
	RageFile* file;
	size_t bytes{ 0 };
	bool stop = false;
};

class Download {
public:
	Download(string url);
	~Download();
	void Install();
	void Update(float fDeltaSeconds);
	void Failed();
	string StartMessage() { return "Downloading file " + m_TempFileName + " from " + m_Url; };
	string Status() { return m_TempFileName + "\n" + speed + " KB/s\n" +
		"Downloaded " + to_string((progress.downloaded>0? progress.downloaded : wt->bytes) / 1024) + (progress.total>0? "/" + to_string(progress.total / 1024) + " (KB)":""); }
	CURL* handle;
	int running;
	ProgressData progress;
	string speed;
	curl_off_t downloadedAtLastUpdate = 0;
	curl_off_t lastUpdateDone = 0;
	RageFile m_TempFile;
	string m_Url;
	WriteThis* wt;
	DownloadablePack* pack;
	string m_TempFileName;
protected:
	string MakeTempFileName(string s);
};

class DownloadablePack {
public:
	string name = "";
	size_t size = 0;
	int id = 0;
	float avgDifficulty = 0;
	string url = "";
	bool downloading = false;
	Download* download;
	// Lua
	void PushSelf(lua_State *L);
};

class DownloadManager
{
public:
	DownloadManager();
	~DownloadManager();
	vector<Download*> downloads;
	CURLM* mHandle{nullptr};
	string aux;
	CURLMcode ret;
	int running;
	bool gameplay;
	string error;
	int lastid;

	vector<DownloadablePack> downloadablePacks;

	Download* DownloadAndInstallPack(const string &url);
	Download*  DownloadAndInstallPack(DownloadablePack* pack);

	bool GetAndCachePackList(string url);

	vector<DownloadablePack>* GetPackList(string url, bool &result);

	void UpdateDLSpeed();
	void UpdateDLSpeed(bool gameplay);

	bool EncodeSpaces(string& str);

	void InstallSmzip(const string &sZipFile);
	
	string GetError() { return error; }
	bool Error() { return error == ""; }
	bool UpdateAndIsFinished(float fDeltaSeconds);

	bool UploadProfile(string url, string file, string user, string pass);

	// Lua
	void PushSelf(lua_State *L);
};

extern DownloadManager* DLMAN;

#endif

#endif