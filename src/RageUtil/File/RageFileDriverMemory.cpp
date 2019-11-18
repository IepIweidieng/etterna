﻿#include "Etterna/Globals/global.h"
#include "RageFile.h"
#include "RageFileDriverMemory.h"
#include "RageUtil/Utils/RageUtil.h"
#include "RageUtil/Utils/RageUtil_FileDB.h"
#include <errno.h>

struct RageFileObjMemFile
{
	RageFileObjMemFile()
	  : m_iRefs(0)
	  , m_Mutex("RageFileObjMemFile")
	{
	}
	RString m_sBuf;
	int m_iRefs;
	RageMutex m_Mutex;

	static void AddReference(RageFileObjMemFile* pFile)
	{
		pFile->m_Mutex.Lock();
		++pFile->m_iRefs;
		pFile->m_Mutex.Unlock();
	}

	static void ReleaseReference(RageFileObjMemFile* pFile)
	{
		pFile->m_Mutex.Lock();
		const int iRefs = --pFile->m_iRefs;
		const bool bShouldDelete = (pFile->m_iRefs == 0);
		pFile->m_Mutex.Unlock();
		ASSERT(iRefs >= 0);

		if (bShouldDelete)
			delete pFile;
	}
};

RageFileObjMem::RageFileObjMem(RageFileObjMemFile* pFile)
{
	if (pFile == NULL)
		pFile = new RageFileObjMemFile;

	m_pFile = pFile;
	m_iFilePos = 0;
	RageFileObjMemFile::AddReference(m_pFile);
}

RageFileObjMem::~RageFileObjMem()
{
	RageFileObjMemFile::ReleaseReference(m_pFile);
}

int
RageFileObjMem::ReadInternal(void* buffer, size_t bytes)
{
	LockMut(m_pFile->m_Mutex);

	m_iFilePos = min(m_iFilePos, GetFileSize());
	bytes = min(bytes, (size_t)GetFileSize() - m_iFilePos);
	if (bytes == 0)
		return 0;
	memcpy(buffer, &m_pFile->m_sBuf[m_iFilePos], bytes);
	m_iFilePos += bytes;

	return bytes;
}

int
RageFileObjMem::WriteInternal(const void* buffer, size_t bytes)
{
	m_pFile->m_Mutex.Lock();
	m_pFile->m_sBuf.replace(m_iFilePos, bytes, (const char*)buffer, bytes);
	m_pFile->m_Mutex.Unlock();

	m_iFilePos += bytes;
	return bytes;
}

int
RageFileObjMem::SeekInternal(int offset)
{
	m_iFilePos = clamp(offset, 0, GetFileSize());
	return m_iFilePos;
}

int
RageFileObjMem::GetFileSize() const
{
	LockMut(m_pFile->m_Mutex);
	return m_pFile->m_sBuf.size();
}

RageFileObjMem::RageFileObjMem(const RageFileObjMem& cpy)
  : RageFileObj(cpy)
{
	m_pFile = cpy.m_pFile;
	m_iFilePos = cpy.m_iFilePos;
	RageFileObjMemFile::AddReference(m_pFile);
}

RageFileObjMem*
RageFileObjMem::Copy() const
{
	RageFileObjMem* pRet = new RageFileObjMem(*this);
	return pRet;
}

const RString&
RageFileObjMem::GetString() const
{
	return m_pFile->m_sBuf;
}

void
RageFileObjMem::PutString(const RString& sBuf)
{
	m_pFile->m_Mutex.Lock();
	m_pFile->m_sBuf = sBuf;
	m_pFile->m_Mutex.Unlock();
}

RageFileDriverMem::RageFileDriverMem()
  : RageFileDriver(new NullFilenameDB)
  , m_Mutex("RageFileDriverMem")
{
}

RageFileDriverMem::~RageFileDriverMem()
{
	for (unsigned i = 0; i < m_Files.size(); ++i) {
		RageFileObjMemFile* pFile = m_Files[i];
		RageFileObjMemFile::ReleaseReference(pFile);
	}
}

RageFileBasic*
RageFileDriverMem::Open(const RString& sPath, int mode, int& err)
{
	LockMut(m_Mutex);

	if (mode == RageFile::WRITE) {
		/* If the file exists, delete it. */
		Remove(sPath);

		RageFileObjMemFile* pFile = new RageFileObjMemFile;

		/* Add one reference, representing the file in the filesystem. */
		RageFileObjMemFile::AddReference(pFile);

		m_Files.push_back(pFile);
		FDB->AddFile(sPath, 0, 0, pFile);

		return new RageFileObjMem(pFile);
	}

	RageFileObjMemFile* pFile =
	  reinterpret_cast<RageFileObjMemFile*>(FDB->GetFilePriv(sPath));
	if (pFile == NULL) {
		err = ENOENT;
		return NULL;
	}

	return new RageFileObjMem(pFile);
}

bool
RageFileDriverMem::Remove(const RString& sPath)
{
	LockMut(m_Mutex);

	RageFileObjMemFile* pFile =
	  reinterpret_cast<RageFileObjMemFile*>(FDB->GetFilePriv(sPath));
	if (pFile == NULL)
		return false;

	/* Unregister the file. */
	FDB->DelFile(sPath);
	vector<RageFileObjMemFile*>::iterator it =
	  find(m_Files.begin(), m_Files.end(), pFile);
	ASSERT(it != m_Files.end());
	m_Files.erase(it);

	RageFileObjMemFile::ReleaseReference(pFile);

	return true;
}

static struct FileDriverEntry_MEM : public FileDriverEntry
{
	FileDriverEntry_MEM()
	  : FileDriverEntry("MEM")
	{
	}
	RageFileDriver* Create(const RString& sRoot) const
	{
		return new RageFileDriverMem();
	}
} const g_RegisterDriver;
