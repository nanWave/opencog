from cython cimport sizeof
from libc.stdlib cimport malloc, free
from libcpp cimport bool
from libcpp.vector cimport vector
from libcpp.set cimport set
from libcpp.map cimport map
from cython.operator cimport dereference as deref, preincrement as inc

from opencog.atomspace import Handle

cdef class PyStatisticData:
    """ C++ StatisticData wrapper class.
    """
    cdef StatisticData *thisptr
    def __cinit__(self, _count, _probability=None, _entropy=None,
                  _interactionInformation=None):
        if _probability is None:
            self.thisptr = new StatisticData(_count)
        else:
            self.thisptr = new StatisticData(_count, _probability, _entropy,
                                             _interactionInformation)
    def __str__(self):
        return "count: {0:d} " \
               "probability: {1:f} " \
               "entropy: {2:f} " \
               "interactionInformation: {3:f}".format(
            self.count,
            self.probability,
            self.entropy,
            self.interactionInformation
        )

    property count:
        def __get__(self): return self.thisptr.count
        def __set__(self, count): self.thisptr.count = count

    property probability:
        def __get__(self): return self.thisptr.probability
        def __set__(self, probability): self.thisptr.probability = probability

    property entropy:
        def __get__(self): return self.thisptr.entropy
        def __set__(self, entropy): self.thisptr.entropy = entropy

    property interactionInformation:
        def __get__(self): return self.thisptr.interactionInformation
        def __set__(self, interactionInformation):
            self.thisptr.interactionInformation = interactionInformation


cdef class PyDataProvider:
    """ C++ DataProvider wrapper class.

    This class wraps the C++ DataProvider class, but this wrapper class supports
    only python long type, since cython binding doesn't support the
    *declaration* of template class now.

    TODO: Change class to support template.
    TODO: Remove the redundant converting code. Cython can convert 'python list'
    <-> 'C++ vector' automatically but can't use now since it has bug.
    (Redefinition error,
    same as https://gist.github.com/mattjj/15f28177d68238659386)
    """
    cdef DataProvider[long] *thisptr

    def __cinit__(self, _n_gram, _isOrderDependent):
        self.thisptr = new DataProvider[long](_n_gram, _isOrderDependent)

    def __dealloc__(self):
        del self.thisptr

    def addOneMetaData(self, meta_data):
        return self.thisptr.addOneMetaData(meta_data)

    def addOneRawDataCount(self, oneRawData, countNum):
        cdef vector[long] v
        for item in oneRawData:
            v.push_back(item)
        self.thisptr.addOneRawDataCount(v, countNum)

    def makeKeyFromData(self, oneRawData, combination_array=None):
        cdef bool *bool_array
        cdef vector[long] v

        for item in oneRawData:
            v.push_back(item)

        if combination_array is None:
            result = self.thisptr.makeKeyFromData(v)
        else:
            bool_array = <bool *>malloc(len(combination_array)*sizeof(bool))

            if bool_array is NULL:
                raise MemoryError()

            for i in xrange(len(combination_array)):
                if combination_array[i]:
                    bool_array[i] = True
                else:
                    bool_array[i] = False

            result = self.thisptr.makeKeyFromData(bool_array, v)
            free(bool_array)

        l = list()
        for item in result:
            l.append(item)
        return l

    def makeDataFromKey(self, indexes):
        cdef vector[long] v
        for item in indexes:
            v.push_back(item)
        return self.thisptr.makeDataFromKey(v)

    def print_data_map(self):
        return self.thisptr.print_data_map().c_str()

    def mDataSet_size(self):
        return deref(self.thisptr.mDataSet).size()

    def find_in_map(self,  oneRawData):
        cdef vector[long] v
        for item in self.makeKeyFromData(oneRawData):
            v.push_back(item)

        cdef map[vector[long], StatisticData].iterator it
        it = self.thisptr.mDataMaps[v.size()].find(v)
        if it == self.thisptr.mDataMaps[v.size()].end():
            return None
        else:
            return PyStatisticData(
                int(deref(it).second.count),
                float(deref(it).second.probability),
                float(deref(it).second.entropy),
                float(deref(it).second.interactionInformation)
            )

    property n_gram:
        def __get__(self): return self.thisptr.n_gram
        def __set__(self, n_gram): self.thisptr.n_gram = n_gram

    property isOrderDependent:
        def __get__(self): return self.thisptr.isOrderDependent
        def __set__(self, isOrderDependent):
            self.thisptr.isOrderDependent = isOrderDependent

cdef class PyProbability:
    """ C++ Probability wrapper class.

    This class wraps the C++ Probability class, but this wrapper class supports
    only python long type, since cython binding doesn't support the
    *declaration* of template class now.

    TODO: Change class to support template.
    """
    @classmethod
    def calculateProbabilities(cls, PyDataProvider provider):
        cdef DataProvider[long] *thisptr = provider.thisptr
        calculateProbabilities(deref(thisptr))

cdef class PyEntropy:
    """ C++ Entropy wrapper class.

    This class wraps the C++ Entropy class, but this wrapper class supports
    only python long type, since cython binding doesn't support the
    *declaration* of template class now.

    TODO: Change class to support template.
    """
    @classmethod
    def calculateEntropies(cls, PyDataProvider provider):
        cdef DataProvider[long] *thisptr = provider.thisptr
        calculateEntropies(deref(thisptr))


class PyDataProviderAtom:
    """ Python DataProvider class for Atom.

    This class wraps the Python DataProvider wrapper class.
    """
    def __init__(self, _n_gram, _isOrderDependent):
        self.provider = PyDataProvider(_n_gram, _isOrderDependent)

    def addOneMetaData(self, atom):
        return self.provider.addOneMetaData(atom.h.value())

    def addOneRawDataCount(self, oneRawData, countNum):
        long_vector = list()
        for atom in oneRawData:
            long_vector.append(atom.h.value())

        self.provider.addOneRawDataCount(long_vector, countNum)

    def makeKeyFromData(self, oneRawData, combination_array=None):
        long_vector = list()
        for atom in oneRawData:
            long_vector.append(atom.h.value())

        if combination_array is None:
            return self.provider.makeKeyFromData(long_vector)
        else:
            return self.provider.makeKeyFromData(long_vector, combination_array)

    def makeDataFromKey(self, atomspace, indexes):
        long_vector = list()
        for index in indexes:
            long_vector.append(index)

        ret_vector = self.provider.makeDataFromKey(long_vector)
        result = list()
        for handle in ret_vector:
            result.append(atomspace[Handle(handle)])

        return result

    def print_data_map(self):
        return self.provider.print_data_map()

    def mDataSet_size(self):
        return self.provider.mDataSet_size()

    def find_in_map(self, oneRawData):
        long_vector = list()
        for atom in oneRawData:
            long_vector.append(atom.h.value())
        return self.provider.find_in_map(long_vector)

    @property
    def n_gram(self):
        return self.provider.n_gram

    @property
    def isOrderDependent(self):
        return self.provider.isOrderDependent

class PyProbabilityAtom:
    """ Python Probability class for Atom.

    This class wraps the Python Probability wrapper class.
    """
    def calculateProbabilities(self, provider_atom):
        PyProbability.calculateProbabilities(provider_atom.provider)

class PyEntropyAtom:
    """ Python Entropy class for Atom.

    This class wraps the Python Entropy wrapper class.
    """
    def calculateEntropies(self, provider_atom):
        PyEntropy.calculateEntropies(provider_atom.provider)
