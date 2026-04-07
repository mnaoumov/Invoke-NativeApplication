using System;
using System.Globalization;
using System.Text;

/// <summary>
/// Wraps a string with an additional IsError property.
/// All string members are delegated to the inner value.
/// </summary>
public class NativeApplicationOutput : IComparable, IComparable<string>, IEquatable<string>
{
    private readonly string _value;

    public bool IsError { get; private set; }
    public int Length { get { return _value.Length; } }

    public char this[int index] { get { return _value[index]; } }

    public NativeApplicationOutput(string value, bool isError)
    {
        _value = value ?? string.Empty;
        IsError = isError;
    }

    // Conversion operators
    public static implicit operator string(NativeApplicationOutput output)
    {
        return output == null ? null : output._value;
    }

    // Object overrides
    public override string ToString() { return _value; }
    public string ToString(IFormatProvider provider) { return _value.ToString(provider); }
    public override int GetHashCode() { return _value.GetHashCode(); }
    public override bool Equals(object obj)
    {
        var other = obj as NativeApplicationOutput;
        if (other != null) return _value.Equals(other._value);
        var s = obj as string;
        if (s != null) return _value.Equals(s);
        return false;
    }

    // IComparable
    public int CompareTo(object value)
    {
        var other = value as NativeApplicationOutput;
        if (other != null) return _value.CompareTo(other._value);
        return _value.CompareTo(value);
    }
    public int CompareTo(string strB) { return _value.CompareTo(strB); }

    // IEquatable<string>
    public bool Equals(string value) { return _value.Equals(value); }
    public bool Equals(string value, StringComparison comparisonType) { return _value.Equals(value, comparisonType); }

    // Clone
    public object Clone() { return _value.Clone(); }

    // Contains
    public bool Contains(string value) { return _value.Contains(value); }

    // CopyTo
    public void CopyTo(int sourceIndex, char[] destination, int destinationIndex, int count)
    {
        _value.CopyTo(sourceIndex, destination, destinationIndex, count);
    }

    // EndsWith
    public bool EndsWith(string value) { return _value.EndsWith(value); }
    public bool EndsWith(string value, StringComparison comparisonType) { return _value.EndsWith(value, comparisonType); }
    public bool EndsWith(string value, bool ignoreCase, CultureInfo culture) { return _value.EndsWith(value, ignoreCase, culture); }

    // IndexOf
    public int IndexOf(char value) { return _value.IndexOf(value); }
    public int IndexOf(char value, int startIndex) { return _value.IndexOf(value, startIndex); }
    public int IndexOf(char value, int startIndex, int count) { return _value.IndexOf(value, startIndex, count); }
    public int IndexOf(string value) { return _value.IndexOf(value); }
    public int IndexOf(string value, int startIndex) { return _value.IndexOf(value, startIndex); }
    public int IndexOf(string value, int startIndex, int count) { return _value.IndexOf(value, startIndex, count); }
    public int IndexOf(string value, StringComparison comparisonType) { return _value.IndexOf(value, comparisonType); }
    public int IndexOf(string value, int startIndex, StringComparison comparisonType) { return _value.IndexOf(value, startIndex, comparisonType); }
    public int IndexOf(string value, int startIndex, int count, StringComparison comparisonType) { return _value.IndexOf(value, startIndex, count, comparisonType); }

    // IndexOfAny
    public int IndexOfAny(char[] anyOf) { return _value.IndexOfAny(anyOf); }
    public int IndexOfAny(char[] anyOf, int startIndex) { return _value.IndexOfAny(anyOf, startIndex); }
    public int IndexOfAny(char[] anyOf, int startIndex, int count) { return _value.IndexOfAny(anyOf, startIndex, count); }

    // Insert
    public string Insert(int startIndex, string value) { return _value.Insert(startIndex, value); }

    // IsNormalized
    public bool IsNormalized() { return _value.IsNormalized(); }
    public bool IsNormalized(NormalizationForm normalizationForm) { return _value.IsNormalized(normalizationForm); }

    // LastIndexOf
    public int LastIndexOf(char value) { return _value.LastIndexOf(value); }
    public int LastIndexOf(char value, int startIndex) { return _value.LastIndexOf(value, startIndex); }
    public int LastIndexOf(char value, int startIndex, int count) { return _value.LastIndexOf(value, startIndex, count); }
    public int LastIndexOf(string value) { return _value.LastIndexOf(value); }
    public int LastIndexOf(string value, int startIndex) { return _value.LastIndexOf(value, startIndex); }
    public int LastIndexOf(string value, int startIndex, int count) { return _value.LastIndexOf(value, startIndex, count); }
    public int LastIndexOf(string value, StringComparison comparisonType) { return _value.LastIndexOf(value, comparisonType); }
    public int LastIndexOf(string value, int startIndex, StringComparison comparisonType) { return _value.LastIndexOf(value, startIndex, comparisonType); }
    public int LastIndexOf(string value, int startIndex, int count, StringComparison comparisonType) { return _value.LastIndexOf(value, startIndex, count, comparisonType); }

    // LastIndexOfAny
    public int LastIndexOfAny(char[] anyOf) { return _value.LastIndexOfAny(anyOf); }
    public int LastIndexOfAny(char[] anyOf, int startIndex) { return _value.LastIndexOfAny(anyOf, startIndex); }
    public int LastIndexOfAny(char[] anyOf, int startIndex, int count) { return _value.LastIndexOfAny(anyOf, startIndex, count); }

    // Normalize
    public string Normalize() { return _value.Normalize(); }
    public string Normalize(NormalizationForm normalizationForm) { return _value.Normalize(normalizationForm); }

    // PadLeft / PadRight
    public string PadLeft(int totalWidth) { return _value.PadLeft(totalWidth); }
    public string PadLeft(int totalWidth, char paddingChar) { return _value.PadLeft(totalWidth, paddingChar); }
    public string PadRight(int totalWidth) { return _value.PadRight(totalWidth); }
    public string PadRight(int totalWidth, char paddingChar) { return _value.PadRight(totalWidth, paddingChar); }

    // Remove
    public string Remove(int startIndex) { return _value.Remove(startIndex); }
    public string Remove(int startIndex, int count) { return _value.Remove(startIndex, count); }

    // Replace
    public string Replace(char oldChar, char newChar) { return _value.Replace(oldChar, newChar); }
    public string Replace(string oldValue, string newValue) { return _value.Replace(oldValue, newValue); }

    // Split
    public string[] Split(params char[] separator) { return _value.Split(separator); }
    public string[] Split(char[] separator, int count) { return _value.Split(separator, count); }
    public string[] Split(char[] separator, StringSplitOptions options) { return _value.Split(separator, options); }
    public string[] Split(char[] separator, int count, StringSplitOptions options) { return _value.Split(separator, count, options); }
    public string[] Split(string[] separator, StringSplitOptions options) { return _value.Split(separator, options); }
    public string[] Split(string[] separator, int count, StringSplitOptions options) { return _value.Split(separator, count, options); }

    // StartsWith
    public bool StartsWith(string value) { return _value.StartsWith(value); }
    public bool StartsWith(string value, StringComparison comparisonType) { return _value.StartsWith(value, comparisonType); }
    public bool StartsWith(string value, bool ignoreCase, CultureInfo culture) { return _value.StartsWith(value, ignoreCase, culture); }

    // Substring
    public string Substring(int startIndex) { return _value.Substring(startIndex); }
    public string Substring(int startIndex, int length) { return _value.Substring(startIndex, length); }

    // ToCharArray
    public char[] ToCharArray() { return _value.ToCharArray(); }
    public char[] ToCharArray(int startIndex, int length) { return _value.ToCharArray(startIndex, length); }

    // ToLower / ToUpper
    public string ToLower() { return _value.ToLower(); }
    public string ToLower(CultureInfo culture) { return _value.ToLower(culture); }
    public string ToLowerInvariant() { return _value.ToLowerInvariant(); }
    public string ToUpper() { return _value.ToUpper(); }
    public string ToUpper(CultureInfo culture) { return _value.ToUpper(culture); }
    public string ToUpperInvariant() { return _value.ToUpperInvariant(); }

    // Trim
    public string Trim() { return _value.Trim(); }
    public string Trim(params char[] trimChars) { return _value.Trim(trimChars); }
    public string TrimEnd(params char[] trimChars) { return _value.TrimEnd(trimChars); }
    public string TrimStart(params char[] trimChars) { return _value.TrimStart(trimChars); }
}
